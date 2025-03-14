TF_VERSION = 1.11

TF_DOCKER_CMD = docker run --rm -it \
	-w /tmp/$(TF_NAME)$(TF_DIRECTORY) \
	-v ~/.aws:/root/.aws:ro \
	-v ~/.ssh:/root/.ssh:ro \
	-v .:/tmp/$(TF_NAME) \
	$(TF_DOCKER_ADDITIONAL) hashicorp/terraform:$(TF_VERSION)

tf_init:
	$(TF_DOCKER_CMD) init

tf_plan:
	$(TF_DOCKER_CMD) plan

tf_apply:
	$(TF_DOCKER_CMD) apply

tf_destroy:
	$(TF_DOCKER_CMD) destroy
