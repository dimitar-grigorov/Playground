# Alpine Linux with Git Docker Image

This Docker image is based on Alpine Linux and includes Git. It serves as a lightweight container for projects that require Git.

## Build Instructions

To build the Docker image locally, follow these steps:

1. Clone the repository:

    ```bash
    git clone https://github.com/dimitar-grigorov/Playground.git
    ```

2. Navigate to the project directory:

    ```bash
    cd Playground/docker-alpine-git
    ```

3. Build the Docker image:

    ```bash
    docker build -t alpine-git .
    ```

## Usage

To use the Docker image:

```bash
docker run -it alpine-git
```

This will start a container with a shell where you can interact with Git and other tools.

## Pushing to Docker Hub

1. Tag your Docker image with your Docker Hub username and repository name:

    ```bash
    docker tag alpine-git grigorov89/alpine-git:latest
    ```

    Replace `grigorov89` with your Docker Hub username and `alpine-git` with the desired repository name.

2. Log in to Docker Hub:

    ```bash
    docker login
    ```

3. Push the Docker image to Docker Hub:

    ```bash
    docker push grigorov89/alpine-git:latest
    ```

    Replace `grigorov89/alpine-git:latest` with your Docker Hub username, repository name, and tag.
