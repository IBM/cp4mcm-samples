# Uploading the Nginx image in an air gap environment

If your environment has no access to Internet, you need to follow the steps to upload the `Nginx` image to all the worker nodes. The `Nginx` container is used for back up MongoDB that is running in the `ibm-common-services` namespace.

## Before you begin
- You need to install the `docker` CLI on a workstation machine, where you can access the internet.

## Procedure

### 1. Log in to the workstation machine, where `docker` CLI is installed.


### 2. Pull the Nginx image by running the following command:

```
docker pull quay.io/bitnami/nginx:latest
```

### 3. Export the Nginx image by running the following command:

```
docker save quay.io/bitnami/nginx:latest -o nginx.tar
```

Move the `nginx.tar` file to the `/tmp` directory in the air gap environment. 

### 4. Log in to the air gap environment.

### 5. Go to the `/tmp` directory by running the following command:

```
cd /tmp
```

### 6. Move the `nginx.tar` to the `/tmp` directory in all the worker nodes.

### 7. Import the Nginx image in each worker node.

  Repeat the following steps 1, 2, and 3 for all the worker nodes.

  1. Log in to the worker node with a `root` user.

  2. Go to the `/tmp` directory by running the following command:

     ```
     cd /tmp
     ```
  3. Import the Nginx image by running the following command:

     ```
     docker load -i nginx.tar
     ```

     If `podman` is installed instead of `docker`, then you need to run the following command to import the Nginx image:

     ```
     podman load -i nginx.tar
     ```