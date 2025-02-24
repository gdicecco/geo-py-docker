# Docker for python projects
This repository contains files and instructions for setting up a docker container for python projects. It includes files for building a docker image with a few common geospatial packages, along with jupyter lab + notebook. The environment is built inside the docker image using either a `conda-lock.yml` file or a conda `environment.yml`, and then pip dependencies are installed using a `requirements.txt` file. The repository also includes a handy-dandy Makefile for building the image and launching a JupyterLab instance from your local machine in the docker container. <br><br>
The repository author is grateful to the [Pangeo community](https://pangeo.io/) for its [open source repository](https://github.com/pangeo-data/pangeo-docker-images/tree/master) for building the pangeo docker images and extensive documentation on their construction. This repository is built off the pangeo docker workflow and recycles code from the Dockerfile for their [base image](https://github.com/pangeo-data/pangeo-docker-images/tree/master/base-image).

## What is docker?  
[Docker](https://www.docker.com/) enables developers to create isolated development environments that can be shared across platforms, avoiding the frustrating issue of passing around conda or pip environments that work on some machines but not others. Docker is a particularly useful tool for developers in the geospatial data space, since many geospatial python packages have complex dependencies that can be challenging to install. 

# The basics: using this repository 
This should all be relatively simply to set up, given that all the required files are included. Modifying the packages in the environment will require a little extra lifting. Otherwise, everything is done for you in the Makefile (see [this section](https://github.com/nicolejkeeney/geo-py-docker/blob/main/README.md#the-makefile) for more info). 

## (1) Setup 
The steps below will only need to be run once! 
1) Make sure that you have the docker app on your local machine, which can be downloaded from [docker.com](https://www.docker.com/). 
2) Clone this repository to your local machine:
```
git clone https://github.com/nicolejkeeney/geo-py-docker
```
4) [OPTIONAL] Customize the environment files to include packages of your preference. **Read the section on [docker images](https://github.com/nicolejkeeney/geo-py-docker/blob/main/README.md#the-docker-image) and [environment files](https://github.com/nicolejkeeney/geo-py-docker/blob/main/README.md#the-environment-files) for more information on this step.** 
5) Build the docker image:
```
make build
```
## (2) Launch JupyterLab from docker container 
Now that you have everything set up locally, you can run your python project in JupyterLab from within a docker container created by the image. Simply run the following code, and then copy-paste the link outputted in terminal into your web browser: 
```
make local
```
When you launch a JupyterLab instance from the docker container, the terminal output will print a link for you to open the JupyterLab in your browser. **You'll need to copy-paste this link into your web browser; it will not automatically open for you.** Use the **bottom** link. See the screenshot below.<br><br>
<img src="images/jupyterlab_link.png" width="850">

# The nitty-gritty 
This section provides a more detailed explanation of the various components of the repository. Not required reading! 

## The docker image 
The image is built from a Dockerfile, which basically just provides the recipe for building the image that your machine then executes. It is built upon a minimal base image; in this case, our base image is ubuntu. The Dockerfile then provides instructions to create a conda environment from the base image by using either the `conda-lock.yml` or `environment.yml` file, then installs any pip dependencies from the `requirements.txt` file. It also sets up the required dependencies for running JupyterLab. 
## The environment files
conda-lock files are recommended over the conda `environment.yml` file for building the docker image. For more information on why this is recommended, refer to the documentation in the [conda-lock repo](https://github.com/conda/conda-lock) on GitHub.<br><br>***IMPORTANT: If you have both a conda-lock.yml and an environment.yml file in your directory, the Makefile will only look at the conda-lock.yml and ignore the environment.yml file***. The image can be built with just an `environment.yml` file, but you'll need to either remove the `conda-lock.yml` file from the directory (recommended) or modify the code in the Dockerfile (not recommended unless you're experienced with docker). <br><br>To create the lockfile, you'll first need an `environment.yml` file with all the conda dependencies listed. And, you'll need to `pip install conda-lock` (refer to the [conda-lock documentation](https://github.com/conda/conda-lock)) Then, you can simply create a multi-platform lockfile by running the command below: 
```
conda-lock -f environment.yml -p osx-64 -p linux-64
```

## The Makefile
The Makefile exists to make the lives of developers easier. It wraps up all the code required to build the image and launch JupyterLab from the container into a single file, allowing the developer to simply run `make build` to build the image and `make local` to launch JupyterLab. <br><br>How is it different from a shell script, you may ask? It doesn't run in parallel like a shell script. You can run isolated sections of code from the same Makefile. For example, `make build` runs just the command for building the image, which you'll only do once, whereas you'll use `make local` anytime you want to open a JupyterLab instance. 

# Find an issue? 
Please reach out if you find any issues in the code or descriptive text. While I've done my best, I'm for the most part a self-taught programmer and I don't have an in-depth understanding of docker. If you find an issue and want to contribute to solving it, please open an [issue](https://github.com/nicolejkeeney/py-geo-docker/issues) in GitHub, shoot me an email, or [open a PR](https://github.com/nicolejkeeney/geo-py-docker/pulls) to fix the problem if you are inclined to do so. 
