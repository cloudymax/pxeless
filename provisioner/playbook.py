#!/usr/bin/python3
# pip install pyyaml
import yaml

f = open('/Users/max/Desktop/Repos/public-infra/ansible/ansible_profiles/loop-flow/main.yaml')

yaml_file = yaml.safe_load(f)
for object in yaml_file:

    print(yaml_file["Groups"])
