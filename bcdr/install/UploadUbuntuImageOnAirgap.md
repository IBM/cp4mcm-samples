# Uploading the Ubuntu image in an air gap environment

If your environment has no access to Internet, you need to follow the steps to upload the `Ubuntu` image to all the worker nodes. The `Ubuntu` container is used for back up MongoDB that is running in the `ibm-common-services` namespace.

## Before you begin
- You need to install the `docker` CLI on a workstation machine, where you can access the internet.

## Procedure

### 1. Log in to the workstation machine, where `docker` CLI is installed.


### 2. Pull the Ubuntu image by running the following command:

```
docker pull quay.io/libpod/ubuntu
```

### 3. Export the Ubuntu image by running the following command:

```
docker save quay.io/libpod/ubuntu -o ubuntu.tar
```

Move the `ubuntu.tar` file to the `/tmp` directory in the air gap environment. 

### 4. Log in to the air gap environment.

### 5. Go to the `/tmp` directory by running the following command:

```
cd /tmp
```

### 6. Move the `ubuntu.tar` to the `/tmp` directory in all the worker nodes.

### 7. Import the Ubuntu image in each worker node.

  Repeat the following steps 1, 2, and 3 for all the worker nodes.

  1. Log in to the worker node with a `root` user.

  2. Go to the `/tmp` directory by running the following command:

     ```
     cd /tmp
     ```
  3. Import the Ubuntu image by running the following command:

     ```
     docker load -i ubuntu.tar
     ```

     If `podman` is installed instead of `docker`, then you need to run the following command to import the Ubuntu image:

     ```
     podman load -i ubuntu.tar
     ```