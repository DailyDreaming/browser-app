# A Custom Docker Image for Running the UCSC Genome Browser.

This downloads the UCSC Genome Browser setup bash script and installs it within the docker image.
It will then be accessible via 127.0.0.1:8001 if that port is
connected ("docker run -p 80:80" or "docker run -p 8001:8001").

To build this image, run (in this directory):

  docker build . -t {docker_username}/{tag_key}:{tag_value}

For example:

  docker build . -t dailydreaming/genome_browser:latest

To push the image to a repository:

  docker login
  docker push {docker_username}/{tag_key}:{tag_value}

For example:

  docker login
  docker push dailydreaming/genome_browser:latest

Then, to run the Genome Browser (running locally on Ubuntu 18.04), something like:

  docker run -p 8001:8001 dailydreaming/genome_browser:latest

Go to 127.0.0.1:8001 in a web browser and you should see the Genome Browser.

To drop into a shell in the currently running browser image, in a separate terminal, find
the current docker ID using "docker ps" and then run:

  docker exec -it {current_docker_id} bash

For example:

  docker exec -it 08d2785718a1 bash
