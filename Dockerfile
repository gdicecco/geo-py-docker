# Dockerfile for building image 
# Based off Dockerfile for pangeo base image 
FROM ubuntu:22.04

# Setup environment to match variables set by repo2docker as much as possible
# The name of the conda environment into which the requested packages are installed
ENV CONDA_ENV=notebook \
    # Tell apt-get to not block installs by asking for interactive human input
    DEBIAN_FRONTEND=noninteractive \
    # Set username, uid and gid (same as uid) of non-root user the container will be run as
    NB_USER=jovyan \
    NB_UID=1000 \
    # Use /bin/bash as shell, not the default /bin/sh (arrow keys, etc don't work then)
    SHELL=/bin/bash \
    # Setup locale to be UTF-8, avoiding gnarly hard to debug encoding errors
    LANG=C.UTF-8  \
    LC_ALL=C.UTF-8 \
    # Install conda in the same place repo2docker does
    CONDA_DIR=/srv/conda

# All env vars that reference other env vars need to be in their own ENV block
# Path to the python environment where the jupyter notebook packages are installed
ENV NB_PYTHON_PREFIX=${CONDA_DIR}/envs/${CONDA_ENV} \
    # Home directory of our non-root user
    HOME=/home/${NB_USER}

# Add both our notebook env as well as default conda installation to $PATH
# Thus, when we start a `python` process (for kernels, or notebooks, etc),
# it loads the python in the notebook conda environment, as that comes
# first here.
ENV PATH=${NB_PYTHON_PREFIX}/bin:${CONDA_DIR}/bin:${PATH}

# Ask dask to read config from ${CONDA_DIR}/etc rather than
# the default of /etc, since the non-root jovyan user can write
# to ${CONDA_DIR}/etc but not to /etc
ENV DASK_ROOT_CONFIG=${CONDA_DIR}/etc

RUN echo "Creating ${NB_USER} user..." \
    # Create a group for the user to be part of, with gid same as uid
    && groupadd --gid ${NB_UID} ${NB_USER}  \
    # Create non-root user, with given gid, uid and create $HOME
    && useradd --create-home --gid ${NB_UID} --no-log-init --uid ${NB_UID} ${NB_USER} \
    # Make sure that /srv is owned by non-root user, so we can install things there
    && chown -R ${NB_USER}:${NB_USER} /srv

# Run conda activate each time a bash shell starts, so users don't have to manually type conda activate
# Note this is only read by shell, but not by the jupyter notebook - that relies
# on us starting the correct `python` process, which we do by adding the notebook conda environment's
# bin to PATH earlier ($NB_PYTHON_PREFIX/bin)
RUN echo ". ${CONDA_DIR}/etc/profile.d/conda.sh ; conda activate ${CONDA_ENV}" > /etc/profile.d/init_conda.sh

# Install basic apt packages
RUN echo "Installing Apt-get packages..." \
    && apt-get update --fix-missing > /dev/null \
    && apt-get install -y apt-utils wget zip tzdata > /dev/null \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
# ========================

USER ${NB_USER}
WORKDIR ${HOME}

# Install latest mambaforge in ${CONDA_DIR}
RUN echo "Installing Mambaforge..." \
    && URL="https://github.com/conda-forge/miniforge/releases/latest/download/Mambaforge-Linux-x86_64.sh" \
    && wget --quiet ${URL} -O installer.sh \
    && /bin/bash installer.sh -u -b -p ${CONDA_DIR} \
    && rm installer.sh \
    && mamba install conda-lock -y \
    && mamba clean -afy \
    # After installing the packages, we cleanup some unnecessary files
    # to try reduce image size - see https://jcristharif.com/conda-docker-tips.html
    # Although we explicitly do *not* delete .pyc files, as that seems to slow down startup
    # quite a bit unfortunately - see https://github.com/2i2c-org/infrastructure/issues/2047
    && find ${CONDA_DIR} -follow -type f -name '*.a' -delete

# Build the conda environment. Install pip dependencies 
# ----------------------
USER root
# FIXME (?): user and home folder is hardcoded for now
# FIXME (?): this line breaks the cache of all steps below
COPY --chown=jovyan:jovyan . /home/jovyan

# If a jupyter_notebook_config.py exists, copy it to /etc/jupyter so
# it will be read by jupyter processes when they start. This feature is
# not available in repo2docker.
RUN echo "Checking for 'jupyter_notebook_config.py'..." \
        ; [ -d binder ] && cd binder \
        ; [ -d .binder ] && cd .binder \
        ; if test -f "jupyter_notebook_config.py" ; then \
        mkdir -p /etc/jupyter \
        && cp jupyter_notebook_config.py /etc/jupyter \
        ; fi

USER ${NB_USER}

# We want to keep our images as reproducible as possible. If a lock
# file with exact versions of all required packages is present, we use
# it to install packages. conda-lock (https://github.com/conda-incubator/conda-lock)
# is used to generate this conda-linux-64.lock file from a given environment.yml
# file - so we get the exact same versions each time the image is built. This
# also lets us see what packages have changed between two images by diffing
# the contents of the lock file between those image versions.
# If a lock file is not present, we use the environment.yml file. 
# After installing the packages, we cleanup some unnecessary files
# to try reduce image size - see https://jcristharif.com/conda-docker-tips.html
RUN echo "Checking for 'conda-lock.yml' 'conda-linux-64.lock' or 'environment.yml'..." \
        ; [ -d binder ] && cd binder \
        ; [ -d .binder ] && cd .binder \
        ; if test -f "conda-lock.yml" ; then \
        conda-lock install --name ${CONDA_ENV} conda-lock.yml \
        ; elif test -f "conda-linux-64.lock" ; then \
        mamba create --name ${CONDA_ENV} --file conda-linux-64.lock \
        ; elif test -f "environment.yml" ; then \
        mamba env create --name ${CONDA_ENV} -f environment.yml  \
        ; else echo "No conda-lock.yml, conda-linux-64.lock, or environment.yml! *creating default env*" ; \
        mamba create --name ${CONDA_ENV} notebook \
        ; fi \
        && mamba clean -yaf \
        && find ${CONDA_DIR} -follow -type f -name '*.a' -delete \
        && find ${CONDA_DIR} -follow -type f -name '*.js.map' -delete \
        ; if [ -d ${NB_PYTHON_PREFIX}/lib/python*/site-packages/bokeh/server/static ]; then \
        find ${NB_PYTHON_PREFIX}/lib/python*/site-packages/bokeh/server/static -follow -type f -name '*.js' ! -name '*.min.js' -delete \
        ; fi

# If a requirements.txt file exists, use pip to install packages
# listed there. We don't want to save cached wheels in the image
# to avoid wasting space.
RUN echo "Checking for pip 'requirements.txt'..." \
        ; [ -d binder ] && cd binder \
        ; [ -d .binder ] && cd .binder \
        ; if test -f "requirements.txt" ; then \
        ${NB_PYTHON_PREFIX}/bin/pip install --no-cache -r requirements.txt \
        ; fi