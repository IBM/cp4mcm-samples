#!/usr/bin/env python
'''
Created on Nov 10, 2020

@author: Shrinath Thube

This script is to 
# Configure Vault
1) Configure HashiCorp vault for IBM CloudPak Multicloud Management - VM Policy controller.
# Feed credentials in three steps
2) (Step 1) Create an empty template to fill VM credentials.
3) (Step 2) Encode private ssh-keys in base64 format and print in the console or create a template using those keys (skipping step 1). This is useful to fill the ssh keys in the empty template. 
4) (Step 3) Push all credentials from the template to HashiCorp Vault.

Input to script 
- Vault URL
- Vault Token
- template File
- SSH private keys directory 
'''

import argparse
import base64
import getopt
import json
import os
from pprint import pprint
import subprocess
import sys
import yaml

class HashiCorpVault(object):
    # object variables needed in the most of the methods
    def __init__(self):
        
        self.vault_url = ''
        self.vault_root_token = ''
        self.policy_name = 'hybrid-grc'
        self.secrets_path = '/data/ssh-keys/vm/'

        # Define the program description
        description_text = 'This program is to configure a HashiCorp Vault for IBM Cloud Pak for Multicloud Management VM Policy controller and push multiple VM credentials in the vault.'
        
        # Define usage
        usage_text = '''vaultfeeder <command> [options]

       vaultfeeder commands are: 
       template     Create an empty yaml template to add a list of target virtual machines information and credentials
       configure    Configure HashiCorp vault for IBM Cloud Pak for Multicloud Management
       feed         Push yaml template data to HashiCorp vault
       base64       Encode all ssh private keys from a provided directory in base64 format
       '''

        parser = argparse.ArgumentParser(description=description_text,usage=usage_text)
        parser.add_argument('command', help='Subcommand to run')
        args = parser.parse_args(args=sys.argv[1:2] if sys.argv[1:] else ['--help'])
        valid_command_list = ['template', 'configure', 'feed', 'base64' ]
        if not hasattr(self, args.command) or args.command not in valid_command_list:
            print ()
            print ('************* Error: %s command not recognized *************' %(args.command))
            print ()
            print ('Displaying vaultfeeder\'s available commands')
            parser.print_help()
            exit(1)
        
        # Call method as per command provided
        getattr(self, args.command)()

    # (Command) feed  
    def feed(self):
        description_text = 'Push VM information and credentials data from yaml template to HashiCorp vault.'
        parser = argparse.ArgumentParser(description=description_text)
        
        parser.add_argument("-u", "--vault_url", help="[Required] hashiCorpo vault URL", required=True)
        parser.add_argument("-t", "--token", help="[Required] hashiCorpo vault root token", required=True)
        parser.add_argument("-p", "--template_path", help="[Required] vm information and credentials yaml template path on local machine", required=True)
        parser.add_argument("-se", "--secret_engine_name", help="[Optional] hashiCorpo vault secret engine and policy name (default value - hybrid-grc)")

        args = parser.parse_args(args=sys.argv[2:] if sys.argv[2:] else ['--help'])

        if args.vault_url:
            self.vault_url = args.vault_url
        if args.token:
            self.vault_root_token = args.token
        if args.template_path:
            template_path = args.template_path
        if args.secret_engine_name:
            self.policy_name = args.secret_engine_name
        
        creds_data = self.read_creds(template_path)
        self.feed_creds_to_vault(creds_data)

    def feed_creds_to_vault(self,creds_data):
        """Push all credentials from template to the Hashicorp Vault.
        """
        # secret engine url
        se_url = self.vault_url + '/v1/' + self.get_secrets_path()
        
        if not self.is_policy_present():
            print("Error: Given secret engine %s is not valid or does not have policy setup. Please configure the vault first using 'vaultfeeder configure' command." %(self.policy_name))
            exit(1)

        app_token = self.create_policy_app_token()
        authorization = 'X-Vault-Token: ' + app_token

        print("Adding secret in the HashiCorp vault at %s" %(self.policy_name))
        for cred in creds_data:
            if not ('secret_name' in cred and cred["secret_name"]):
                print("Secret name is not valid")
                continue
            query_url = se_url + cred["secret_name"]
            content = {}
            content['data'] = cred["data"]
            cmd = ['curl','-k' ,'-H', authorization ,'-H','Content-type: application/json','-d' , json.dumps(content) ,'-X' ,'POST' ,query_url ]
            # print (cmd)
            try:
                proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
                out,err = proc.communicate()
                response = json.loads(out)
                if not response:
                    print("Could not add secret for %s" %(cred["secret_name"]))
                print("Successfully added secret for %s " %(cred["secret_name"]))
            except Exception as err:
                print("Error: Something wrong with query ", query_url, err)

    def read_creds(self,filePath):
        """ Read credentials file (yaml format) from local machine.
        """
        try:
            with open(filePath) as f:
                creds_data = yaml.safe_load(f)        #json.load() -- for reading json file
            print ("finished reading template file")
            return creds_data["all_creds"]
        except Exception as err:
            print (err)

    def create_policy_app_token(self):
        """ Create and return a token, specific to the policy. Token will have only defined secret engine's access and not all vault access.
        """
        if not self.is_policy_present():
            print("%s policy is not present in the vault" %(self.policy_name))
            exit(1)

        query_url = self.vault_url + '/v1/auth/token/create'
        authorization = 'X-Vault-Token: ' + self.vault_root_token
        app_token_ttl = "5h"
        payload = {"policies":[self.policy_name], "meta": {"user": self.policy_name } , "ttl": app_token_ttl , "renewable": True }
        
        cmd = ['curl','-k' ,'-H', authorization ,'-H','Content-type: application/json','-d' , json.dumps(payload) ,'-X' ,'POST' ,query_url ]
        try:
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
            out,err = proc.communicate()        
            response = json.loads(out)
            if not response["auth"]["client_token"]:
                print("Could not create policy token. Vault reponse - ", response, err)
                exit(1)
            print("Successfully created %s policy token" %(self.policy_name))
            return response["auth"]["client_token"]
        except Exception as err:
            print ("Something is wrong with query - ",err)
            print ("Check provided URL - ",self.vault_url)
            exit(1)

    # (Command) template
    def template(self):
        """It is a command to create an empty template. User will add VM information in the template. 
        """
        description_text = 'Create an empty yaml template to add list of target virtual machines information and credential.'
        parser = argparse.ArgumentParser(description=description_text)
        
        parser.add_argument("-p", "--template_path", help="[Optional] target template name. If not provided default name is 'sample_vm_creds_template.yaml'")

        args = parser.parse_args(args=sys.argv[2:])

        if args.template_path:
            self.create_template(args.template_path)
        else:
            self.create_template('sample_vm_creds_template.yaml')

    # *************************************************
    def check_template_validity(self):
        pass
    # *************************************************

    # (Command) congigure
    def configure(self):
        description_text = '''Configure HashiCorp vault for IBM Cloud Pak for Multicloud Management
        1) Create and enable a new key-value secret engine.
        2) Add vault policy for newly created secret engine.
        '''
        parser = argparse.ArgumentParser(description=description_text)
        
        parser.add_argument("-u", "--vault_url", help="[Required] hashiCorpo vault URL", required=True)
        parser.add_argument("-t", "--token", help="[Required] hashiCorpo vault root token", required=True)
        parser.add_argument("-se", "--secret_engine_name", help="[Optional] hashiCorpo vault secret engine and policy name (default value - hybrid-grc)")

        args = parser.parse_args(args=sys.argv[2:] if sys.argv[2:] else ['--help'])

        if args.vault_url:
            self.vault_url = args.vault_url
        if args.token:
            self.vault_root_token = args.token
        if args.secret_engine_name:
            self.policy_name = args.secret_engine_name

        if self.create_enable_secret_kv_engine():
            print("Here it is")
            print("Successfully created ",self.policy_name," secret engine")
        self.create_policy_for_secret_engine()
        self.add_sample_secret()

    def create_policy_for_secret_engine(self):

        policy_data = "# Allow a token to perform CURD capabilities only in the vm directory\n path \"%s/data/ssh-keys/vm/*\" {\n capabilities = [\"create\", \"read\", \"update\", \"delete\"] \n }\n path \"%s/metadata/*\" {\n capabilities = [\"list\"]\n }" %(self.policy_name,self.policy_name)
        vault_policy = {}
        vault_policy["policy"] = policy_data
        
        query_url = self.vault_url + '/v1/sys/policy/' + self.policy_name
        authorization = 'X-Vault-Token: ' + self.vault_root_token
        cmd = ['curl','-k' ,'-H', authorization ,'-H','Content-type: application/json','-d' , json.dumps(vault_policy) ,'-X' ,'PUT' ,query_url ]
        print("Creating policy")
        try:
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            out,err = proc.communicate()        
            if out != b'' or err != b'':
                print("query error, got following response for creating policy - ", out, err)
                print(self.query_errors(err))
                print()
                exit(1)
        except Exception as err:
            print (err)
            exit(1)
        print("Successfully created %s policy" %(self.policy_name))

    def is_policy_present(self):
        """Check if policy for secret engine has added or not. If present return True or False. 
        """
        query_url = self.vault_url + '/v1/sys/policy/' + self.policy_name
        authorization = 'X-Vault-Token: ' + self.vault_root_token
        cmd = ['curl','-k' ,'-H', authorization ,'-H','Content-type: application/json', '-X' ,'GET' ,query_url ]

        try:
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
            out,err = proc.communicate()   
            response = json.loads(out)
            if "errors" in response:
                return False
            return True
        except Exception as err:
            print("I am here policy")
            print ("Something is wrong with query - ",err)
            print ("Check provided URL - ",self.vault_url)
            print()
            exit(1)

    # Curl error logs
    def query_errors(self,query):
        if 'SSL_ERROR_SYSCALL' in str(query):
            return "ERROR: Most probably, the Vault service is not running or unreachable."
        if 'Could not resolve host' in str(query):
            return "ERROR: Check Vault URL."

    def create_enable_secret_kv_engine(self):
        query_url = self.vault_url + '/v1/sys/mounts/' + self.policy_name 
        authorization = 'X-Vault-Token: ' + self.vault_root_token
        payload =  { "type": "kv-v2" }
        cmd = ['curl','-k' ,'-H', authorization ,'-H','Content-type: application/json','-d' , json.dumps(payload) ,'-X' ,'POST' ,query_url ]
        print("Creating and enabling secret engine")
        try:
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            out,err = proc.communicate()
            if out != b'' or err != b'':
                print("Query error, got the following response for enabling secret engine - ", out, err)
                print(self.query_errors(err))
                print()
                return False
        except Exception as err:
            print("I am here")
            print ("Something is wrong with query - ",err)
            print ("Check provided URL - ",self.vault_url)
            exit(1)
        return True

    def get_secrets_path(self):
        return self.policy_name + self.secrets_path

    def is_sample_secret_present(self):
        query_url = self.vault_url + '/v1/' + self.get_secrets_path() + 'sample-secret'
        authorization = 'X-Vault-Token: ' + self.vault_root_token

        cmd = ['curl','-k' ,'-H', authorization ,'-X' ,'GET' ,query_url ]
        # print (cmd)
        try:
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
            out,err = proc.communicate()
            response = json.loads(out)
            if "errors" in response:
                return False
            return True
        except Exception as err:
            print ("Something is wrong with query - ",err)
            print ("Check provided URL - ",self.vault_url)
            print()
            exit(1)

    def add_sample_secret(self):
        """After configuring Vault, add sample credential secret for reference and to create path.
        """
        if self.is_sample_secret_present():
            print("sample-secret is already present at %s path " %(self.get_secrets_path()))
            return
        
        ip_as_secret_name = {}
        ip_as_secret_name['data'] = {}
        ip_as_secret_name['data']['ansible_become_password'] = "<privilege_user's_password>"
        ip_as_secret_name['data']['ansible_become_user'] = "<privilege_username>"
        ip_as_secret_name['data']['hostname'] = "<VM_Public_IP_Address>"
        ip_as_secret_name['data']['passphrase'] = "<sshkey_passphrase>" 
        ip_as_secret_name['data']['sshkey'] = "<base64_encoded_private_ssh_key_for_remote_login>"
        ip_as_secret_name['data']['user'] = "<remote_user_name>"

        query_url = self.vault_url + '/v1/' + self.get_secrets_path() + 'sample-secret'
        authorization = 'X-Vault-Token: ' + self.vault_root_token

        cmd = ['curl','-k' ,'-H', authorization ,'-H','Content-type: application/json','-d' , json.dumps(ip_as_secret_name) ,'-X' ,'POST' ,query_url ]
        print ("Adding sample-secret at %s path" %(self.get_secrets_path()))
        try:
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
            out,err = proc.communicate()
            response = json.loads(out)
            if not response:
                return False
            print("Successfully added sample secret ", response)
            return True
        except Exception as err:
            print (err)

    # (Command) base64
    def base64(self):
        # object variables needed in the most of the methods
        self.vault_url = ''
        self.vault_root_token = ''
        self.policy_name = 'hybrid-grc'
        self.secrets_path = '/data/ssh-keys/vm/'
        # Define the program description
        description_text = 'Encode and print all ssh private keys from a provided directory in base64 format.'
        
        # Define usage
        usage_text = '''vaultfeeder base64 <subcommand> [options]

       'vaultfeeder base64' subcommands are: 
       build   Create an empty yaml template with added base64 encoded private keys in it
       display    Print all ssh private keys base64 encoded value
       '''

        parser = argparse.ArgumentParser(description=description_text,usage=usage_text)
        parser.add_argument('subcommand', help='Subcommand to run')
        args = parser.parse_args(args=sys.argv[2:3] if sys.argv[2:] else ['--help'])
        valid_command_list = ['build', 'display']
        if not hasattr(self, args.subcommand) or args.subcommand not in valid_command_list:
            print ()
            print ('************* Error: %s command not recognized *************' %(args.subcommand))
            print ()
            print ('Displaying vaultfeeder\'s available commands')
            parser.print_help()
            exit(1)
        # Call method as per command provided
        getattr(self, args.subcommand)()

    # (Sub command of base64) build
    def build(self):
        description_text = '''Encode all ssh private keys from a provided directory in base64 format, create an empty template and add keys in it.'''
        parser = argparse.ArgumentParser(description=description_text)

        parser.add_argument("-k", "--ssh_key_dir", help="[Required] private ssh keys directory path", required=True)
        parser.add_argument("-p", "--template_path", help="[Optional] target template name. If not provided default name is 'sample_vm_creds_template.yaml'")

        args = parser.parse_args(args=sys.argv[3:] if sys.argv[3:] else ['--help'])

        if args.ssh_key_dir:
            ssh_key_dir = args.ssh_key_dir
        
        template_path = 'sample_vm_creds_with_keys_template.yaml'
        if args.template_path:
            template_path = args.template_path
        
        self.build_template(ssh_key_dir,template_path)
        # self.add_keys_into_template(template_path)

    def build_template(self,ssh_key_dir,template_path):
        """Base64 encode all ssh keys from given directory. Create yaml template and add encoded values in it.
        """
        # varify template name validity
        if not template_path:
            template_path = 'sample_vm_creds_template.yaml'
        elif not template_path.endswith(('.yaml','.yml')):
            template_path += '.yaml'
        if os.path.isfile(template_path):
            print("%s template is already present. Use differnt name if you want to create new." %(template_path))
            sys.exit(1)

        # verify directory validity 
        if not os.path.exists(ssh_key_dir):
            print("Error: Given ssh key directory path is not valid - ", ssh_key_dir)
            exit(1)
        # list all files from given ssh key directory
        ssh_file_list = [fileName for fileName in os.listdir(ssh_key_dir) if os.path.isfile(os.path.join(ssh_key_dir,fileName))]
        print("Number of keys in the directory ", len(ssh_file_list))
        if len(ssh_file_list) == 0:
            print("Given directory is empty ", ssh_key_dir)

        template_text = self.get_template_warning('sshkeys')

        creds_template = {}
        creds_template['all_creds'] = []

        for keyFileName in ssh_file_list:
            # build vm credential dictionary
            vm_secret_name = {}
            vm_secret_name['secret_name'] = ("<Filename - %s REPLACE THIS FIELD WITH VM_Public_IP_Address or VM_Public_Hostname or 'VM_tag_key/tag_value' same as data.hostname field's value>" % keyFileName)
            vm_secret_name['data'] = {}
            vm_secret_name['data']['ansible_become_password'] = "<privilege_user's_password>"
            vm_secret_name['data']['ansible_become_user'] = "<privilege_username>"
            vm_secret_name['data']['hostname'] = "<VM_Public_IP_Address or VM_Public_Hostname or 'VM_tag_key/tag_value'>"
            vm_secret_name['data']['passphrase'] = "<sshkey_passphrase>" 
            vm_secret_name['data']['user'] = "<remote_user_name>"

            # read file encode in base64 format
            keyFileName = os.path.join(ssh_key_dir,keyFileName)
            try:
                with open(keyFileName,'rb') as binary_key:
                    data = binary_key.read()
                    base64_encoded_data = base64.b64encode(data)
                    base64_msg = base64_encoded_data.decode('utf-8')
                    vm_secret_name['data']['sshkey'] = base64_msg
                    creds_template['all_creds'].append(vm_secret_name)
            except Exception as err:
                print("ERROR: For Base64 encoding filename - ",keyFileName)
                print(err)
        
        if not creds_template['all_creds']:
            print("ERROR: Don't have keys to build template, Could not create template")
            return False

        # dump list of dict in the template yaml file, width paramerter is to avoid wrapping long string
        with open(template_path, 'w') as f:
            f.write(template_text)
            yaml.safe_dump(creds_template, f, width=2000)    

        print(template_path," has created")
        return True

    # (Sub command of base64) display
    def display(self):

        description_text = '''Encode and print all ssh private keys from provided directory in base64 format.  '''
        parser = argparse.ArgumentParser(description=description_text)

        parser.add_argument("-k", "--ssh_key_dir", help="[Required] private ssh keys directory path", required=True)

        args = parser.parse_args(args=sys.argv[3:] if sys.argv[3:] else ['--help'])

        if args.ssh_key_dir:
            self.base64_encode_key(args.ssh_key_dir)


    def base64_encode_key(self,ssh_key_dir):
        """Display base64 encoded values of all files from given directory.
        """
        if not os.path.exists(ssh_key_dir):
            print("Error: Given ssh key directory path is not valid - ", ssh_key_dir)
            exit(1)

        ssh_file_list = [fileName for fileName in os.listdir(ssh_key_dir) if os.path.isfile(os.path.join(ssh_key_dir,fileName))]

        print("Number of keys in the directory ", len(ssh_file_list))
        if len(ssh_file_list) == 0:
            print("Given directory is empty ", ssh_key_dir)

        for keyFileName in ssh_file_list:
            print("*"*100)
            print("*"*15,"Base64 encoding filename - ",keyFileName,"*"*15)
            print("*"*100)
            keyFileName = os.path.join(ssh_key_dir,keyFileName)
            try:
                with open(keyFileName,'rb') as binary_key:
                    data = binary_key.read()
                    base64_encoded_data = base64.b64encode(data)
                    base64_msg = base64_encoded_data.decode('utf-8')
                    print(base64_msg)
                print("*"*100)
                print()
                print()
            except Exception as err:
                print(err)
    
    def get_template_warning(self, template_purpose):
        """Warning notice to add in the yaml template.
        """
        template_text = ''
        if template_purpose.lower() == 'empty':
            template_text = ("##################################################################################################################################",
            "### ******!!!!! WARNING: - THIS TEMPLATE WILL HAVE CRITICAL, SENSITIVE INFORMATION REGARDING VMs.                   !!!!!******###",
            "### ******!!!!!            DO NOT SHARE WITH UNAUTHORIZE PERSON. ENCRYPT IT AND KEEP IT SAFE OR DELETE IT AFTER USE.!!!!!******###",
            "##################################################################################################################################",
            "### This is an empty template. You can add vm credentials by three ways.                                                       ###",
            "### 1) secret name as VM 'public IP address'. (example 'a.b.c.d')                                                               ###",
            "### 2) secret name as VM 'public Hostname'.   (example 'example-hostname.com')                                                  ###",
            "### 3) secret name as VM 'tag_key/tag_value'. (example 'environment/production')                                                ###",
            "### Each data block has one VM information and accessing credentials. Copy and past data block to add any number of VMs.       ###",
            "### Way 1 & 2 is for those VMs who have unique ssh keys and credentials to do ssh login.                                       ###",
            "### Way 3 is for those VMs who have same tags and same ssh keys and credentials to do ssh login.                               ###",
            "### Tags information should have assined in the Infrastructure management of IBM Cloud Pak for Multicloud Management.          ###",
            "##################################################################################################################################"
            )

        elif template_purpose.lower() == 'sshkeys':
            template_text = ("##################################################################################################################################",
            "### ******!!!!! WARNING: - THIS TEMPLATE WILL HAVE CRITICAL, SENSITIVE INFORMATION REGARDING VMs.                   !!!!!******###",
            "### ******!!!!!            DO NOT SHARE WITH UNAUTHORIZE PERSON. ENCRYPT IT AND KEEP IT SAFE OR DELETE IT AFTER USE.!!!!!******###",
            "##################################################################################################################################",
            "### This template added base64 encoded ssh-keys. You need to update rest of the information to use it. Here ssh-key name has   ###",
            "### been added in the secret name field to identify the key. You need to replace secret name with vm information.              ###",
            "### You can modify secret name and add vm credentials by three ways.                                                           ###",
            "### 1) secret name as VM 'public IP address'. (example 'a.b.c.d')                                                               ###",
            "### 2) secret name as VM 'public Hostname'.   (example 'example-hostname.com')                                                  ###",
            "### 3) secret name as VM 'tag_key/tag_value'. (example 'environment/production')                                                ###",
            "### Each data block has one VM information and accessing credentials. Copy and past data block to add any number of VMs.       ###",
            "### Way 1 & 2 is for those VMs who have unique ssh keys and credentials to do ssh login.                                       ###",
            "### Way 3 is for those VMs who have same tags and same ssh keys and credentials to do ssh login.                               ###",
            "### Tags information should have assined in the Infrastructure management of IBM Cloud Pak for Multicloud Management.          ###",
            "##################################################################################################################################"
            )
        return '\n'.join(template_text) + '\n'

    def create_template(self,fileName):
        """Create an empty template yaml to add vm credentials.
        """
        if not fileName:
            fileName = 'sample_vm_creds_template.yaml'
        elif not fileName.endswith(('.yaml','.yml')):
            fileName += '.yaml'
        
        if os.path.isfile(fileName):
            print("%s template is already present. Use differnt name if you want to create new." %(fileName))
            sys.exit(1)

        template_text = self.get_template_warning('empty')
        creds_template = {}
        creds_template['all_creds'] = []
        ip_as_secret_name = {}
        ip_as_secret_name['secret_name'] = "<VM_Public_IP_Address>"
        ip_as_secret_name['data'] = {}
        ip_as_secret_name['data']['ansible_become_password'] = "<privilege_user's_password>"
        ip_as_secret_name['data']['ansible_become_user'] = "<privilege_username>"
        ip_as_secret_name['data']['hostname'] = "<VM_Public_IP_Address>"
        ip_as_secret_name['data']['passphrase'] = "<sshkey_passphrase>" 
        ip_as_secret_name['data']['sshkey'] = "<base64_encoded_private_ssh_key_for_remote_login>"
        ip_as_secret_name['data']['user'] = "<remote_user_name>"

        hostname_as_secret_name = {}
        hostname_as_secret_name['secret_name'] = "<VM_Public_Hostname>"
        hostname_as_secret_name['data'] = {}
        hostname_as_secret_name['data']['ansible_become_password'] = "<privilege_user's_password>"
        hostname_as_secret_name['data']['ansible_become_user'] = "<privilege_username>"
        hostname_as_secret_name['data']['hostname'] = "<VM_Public_Hostname>"
        hostname_as_secret_name['data']['passphrase'] = "<sshkey_passphrase>" 
        hostname_as_secret_name['data']['sshkey'] = "<base64_encoded_private_ssh_key_for_remote_login>"
        hostname_as_secret_name['data']['user'] = "<remote_user_name>"

        tag_as_secret_name = {}
        tag_as_secret_name['secret_name'] = "<VM_tag_key/tag_value>"
        tag_as_secret_name['data'] = {}
        tag_as_secret_name['data']['ansible_become_password'] = "<privilege_user's_password>"
        tag_as_secret_name['data']['ansible_become_user'] = "<privilege_username>"
        tag_as_secret_name['data']['hostname'] = "<VM_tag_key/tag_value>"
        tag_as_secret_name['data']['passphrase'] = "<sshkey_passphrase>" 
        tag_as_secret_name['data']['sshkey'] = "<base64_encoded_private_ssh_key_for_remote_login>"
        tag_as_secret_name['data']['user'] = "<remote_user_name>"

        creds_template['all_creds'].append(ip_as_secret_name)
        creds_template['all_creds'].append(hostname_as_secret_name)
        creds_template['all_creds'].append(tag_as_secret_name)

        #pprint(creds_template) 
        with open(fileName, 'w') as f:
            f.write(template_text)
            yaml.safe_dump(creds_template, f)    

        print(fileName," has created")
        return True

def main():
    HashiCorpVault()

if __name__ == '__main__':
    main()