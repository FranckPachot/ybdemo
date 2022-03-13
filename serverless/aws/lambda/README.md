```
mkdir -p ~/cloud/aws-cli
type ~/cloud/aws-cli/aws 2>/dev/null || ( mkdir -p ~/cloud/aws-cli && cd /var/tmp && rm -rf /var/tmp/aws && wget -qc https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip && unzip -qo awscli-exe-linux-$(uname -m).zip && ./aws/install --update --install-dir ~/cloud/aws-cli --bin-dir ~/cloud/aws-cli )
export PATH="$HOME/cloud/aws-cli:$PATH"
aws configure
aws sts get-caller-identity
```
