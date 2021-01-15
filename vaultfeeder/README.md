# vaultfeeder

The primary focus of this tool is to 

**Configure Vault**
1) Configure HashiCorp vault for IBM CloudPak Multicloud Management - VM Policy controller.

**Feed credentials in the vault in two/three steps**

2) (Step 1) Create an empty template for the user to fill VM credentials in it.
3) (Step 2) Encode private ssh-keys in base64 format and print in the console or create a template using those keys (skipping step 1). This is useful to fill the ssh keys in the empty template. It is one of the attributes of VM information. 
4) (Step 3) Push all credentials from the template to HashiCorp Vault.

Refer: https://www.ibm.com/support/knowledgecenter/SSFC4F_2.0.0/mcm/compliance/vmpolicy_vault.html

# Installation

```
pip install -e git+https://github.com/IBM/cp4mcm-samples.git#egg=vaultfeeder\&subdirectory=vaultfeeder
```

# Usage

```
usage: vaultfeeder <command> [options]

       vaultfeeder commands are:
       template     Create an empty yaml template to add list of target virtual machines information and credentials
       configure    Configure HashiCorp vault for IBM Cloud Pak for Multicloud Management
       feed         Push yaml template data to HashiCorp vault
       base64       Encode all ssh private keys from provided directory in base64 format


This program is to configure a HashiCorp Vault for IBM Cloud Pak for
Multicloud Management VM Policy controller and push multiple VM credentials in
the vault.

positional arguments:
  command     Subcommand to run

optional arguments:
  -h, --help  show this help message and exit
```

## Configure vault

vaultfeeder configures provided HashiCorp Vault as per VM policy controller needed. It creates a secret-engine name as 'hybrid-grc' by default and configures a policy for the secret-engine. Secret-engine is used for storing VMs credentials. 

```
$ vaultfeeder configure -h

usage: vaultfeeder [-h] -u VAULT_URL -t TOKEN [-se SECRET_ENGINE_NAME]

Configure HashiCorp vault for IBM Cloud Pak for Multicloud Management 1)
Create and enable new key value secret engine 2) Add vault policy for newly
created secret engine

optional arguments:
  -h, --help            show this help message and exit
  -u VAULT_URL, --vault_url VAULT_URL
                        [Required] hashiCorpo vault URL
  -t TOKEN, --token TOKEN
                        [Required] hashiCorpo vault root token
  -se SECRET_ENGINE_NAME, --secret_engine_name SECRET_ENGINE_NAME
                        [Optional] hashiCorpo vault secret engine and policy
                        name (default value - hybrid-grc)
```

**Required argument needed for this commands are** 
1) VAULT_URL - Accessible URL link of a vault. 
2) TOKEN - HashiCorp vault's root token to access the vault.

**Optional parameter**
1) SECRET_ENGINE_NAME - It is the name of KV (key-value) storage/secret-engine of Vault. The recommended name is 'hybrid-grc', the user can use a different name.

## Create an empty template

Creates a YAML template where a user needs to fill VMs credentials. Vaultfeeder will read it and push the information in the given vault. 

**Note: Template will have sensitive information. Delete the template after use or encrypt and store it in a secure place.**

```
$ vaultfeeder template -h

usage: vaultfeeder [-h] [-p TEMPLATE_PATH]

Create an empty yaml template to add list of target virtual machines
information and credential

optional arguments:
  -h, --help            show this help message and exit
  -p TEMPLATE_PATH, --template_path TEMPLATE_PATH
                        [Optional] target template name. If not provided
                        default name is 'sample_vm_creds_template.yaml'
```

**Optional parameter**
1) TEMPLATE_PATH - User can provide template name and path where to store before creating an empty template

## Encode keys in base64 format

```
$ vaultfeeder base64 -h

usage: vaultfeeder base64 <subcommand> [options]

       'vaultfeeder base64' subcommands are:
       build   Create an empty yaml template with added base64 encoded private keys in it
       display    Print all ssh private keys base64 encoded value


Encode and print all ssh private keys from provided directory in base64 format

positional arguments:
  subcommand  Subcommand to run

optional arguments:
  -h, --help  show this help message and exit
```


### Encode and display

Encode the private ssh keys in base64 format and display them in the console. This is useful to add keys in a template. 

```
$ vaultfeeder base64 display -h

usage: vaultfeeder [-h] -k SSH_KEY_DIR

Encode and print all ssh private keys from provided directory in base64
format.

optional arguments:
  -h, --help            show this help message and exit
  -k SSH_KEY_DIR, --ssh_key_dir SSH_KEY_DIR
                        [Required] private ssh keys directory path
```

### Encode and build new template

Creates a template by adding encoded private ssh keys in base64 format. The user needs to verify the added keys and fill in the rest of the information in the template. This will skip the steps of creating a template and efforts to copy and paste the encoded values in the template manually.

```
$ vaultfeeder base64 build -h

usage: vaultfeeder [-h] -k SSH_KEY_DIR [-p TEMPLATE_PATH]

Encode all ssh private keys from provided directory in base64 format, create
an empty template and add keys in it

optional arguments:
  -h, --help            show this help message and exit
  -k SSH_KEY_DIR, --ssh_key_dir SSH_KEY_DIR
                        [Required] private ssh keys directory path
  -p TEMPLATE_PATH, --template_path TEMPLATE_PATH
                        [Optional] target template name. If not provided
                        default name is 'sample_vm_creds_template.yaml'
```

## Push credentials to vault

vaultfeeder reads the completed template and push its content in the given vault.

```
$ vaultfeeder feed -h

usage: vaultfeeder [-h] -u VAULT_URL -t TOKEN -p TEMPLATE_PATH
                   [-se SECRET_ENGINE_NAME]

Push vm information and credentials data from yaml template to HashiCorp vault

optional arguments:
  -h, --help            show this help message and exit
  -u VAULT_URL, --vault_url VAULT_URL
                        [Required] hashiCorpo vault URL
  -t TOKEN, --token TOKEN
                        [Required] hashiCorpo vault root token
  -p TEMPLATE_PATH, --template_path TEMPLATE_PATH
                        [Required] vm information and credentials yaml
                        template path on local machine
  -se SECRET_ENGINE_NAME, --secret_engine_name SECRET_ENGINE_NAME
                        [Optional] hashiCorpo vault secret engine and policy
                        name (default value - hybrid-grc)
```

**Required argument needed for this commands are** 
1) VAULT_URL - Accessible URL link of a vault. 
2) TOKEN - HashiCorp vault's root token to access the vault.
3) TEMPLATE_PATH - YAML template containing VM credentials. vaultfeeder will push those in the vault.

**Optional parameter**
1) SECRET_ENGINE_NAME - It is the name of KV (key-value) storage/secret-engine of Vault. The recommended name is 'hybrid-grc', the user can use a different name.


# Contributing
Pull requests are very welcome! Make sure that your patches are tested. Ideally create a topic branch for every separate change you make. For example:

1. Fork the repo
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

**Note:** Make sure you update the [Changelog](CHANGELOG.md) each time you add, remove, or update sample files.

# License & Authors

If you would like to see the detailed LICENSE click [here](LICENSE).

- Author: New OpenSource IBMer <new-opensource-ibmer@ibm.com>

```text
Copyright:: 2019- IBM, Inc

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```


[issues]: https://github.com/IBM/repo-template/issues/new
