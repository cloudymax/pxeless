#!/usr/bin/env python3
"""
Python program to build the boilerplate infrastructure needed to
properly take over an environment and provide a homogenous base
from which to run/deploy IaC. Several of these functions are borrowed 
from io_tools and will be excized form this script at a later time,
and rolled back into that package
"""

import json
import yaml
from yaml.loader import SafeLoader
import logging as log
from logging import debug
import shutil
import os
import requests
import sys
import time
import io
import math 

vm_config_path = "/home/max/public-infra/virtual-machines/quemu/configs/qemu-vm.yaml"

log_level = log.INFO
program_log = log.getLogger(f"qemu-py")
log.basicConfig(level=log_level)
program_log.info("logging config loaded")

# from io_tools
def read_yaml_file(yaml_file_path):
    """
    Reads a .yaml file as raw, converts to json, formats it, then reloads 
    it as a dict for uniformity of transformation later
    """

    with open(yaml_file_path, 'r') as f:

        # reads the files as raw - unusable until loaded
        raw = f.read()
        #print(raw)

        # converts the raw data into a json string
        yaml_object = yaml.safe_load(raw)
        #print(yaml_object)

        # pretty format the json to make it uniform
        json_data = json.dumps(yaml_object, separators=(',', ":"))
        #print(json_data)

        # Load the clean json into a python dict
        json_object = json.loads(f"{json_data}")
        #print(json_object)

    return json_object

# from io_tools
def make_dir(path: str, clear: bool = False, debug: bool = False,
             format="json"):
    """
    makes/deletes directory
    """
    # if the directory does not exist, try to create it
    if not os.path.isdir(path):
        program_log.info(f'Directory is not present. Creating {path}')
        try:
            os.makedirs(path)
        except Exception as e:
            program_log.error(f"Oof", print(e.__class__), "occurred")
            program_log.error(f"Unable to create dir at {path}")
            if debug:
                name = input("Any key to continue")
    else:
    # if the directory DOES exist, notify that we will be removing and
    # overwriting it
        if not clear:
            program_log.info(f'Deleting directory: {path}')
            program_log.info('clearing...')
        try:
            shutil.rmtree(path)
            os.makedirs(path)
        except Exception as e:
            program_log.error(f"Oof", print(e.__class__), "occurred")
            program_log.error(f"failed to clear directory: {path}")
            if debug:
                name = input("Any key to continue")

# should add to io_tools
def convert_size(size_bytes):
   if size_bytes == 0:
       return "0B"
   size_name = ("B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB")
   i = int(math.floor(math.log(size_bytes, 1024)))
   p = math.pow(1024, i)
   s = round(size_bytes / p, 2)
   return "%s %s" % (s, size_name[i])

# should add to io_tools
def download_file(url: str, output_name: str):
    """
    Downloads a file and shows a simple progress bar
    furmulas are:
       Filled bar percentage: bar_length * downloaded_bytes / total_bytes
       Download progress: (downloaded_bytes/total_bytes) * 100
       Download speed: (downloaded_bytes // time_elapsed) / 100000
       Character to fill the bar: 
            left: '*' * bar_fill
            right: ' ' * (bar_length - bar_fill)
    """
    with io.BytesIO() as f:
        print(f"Downloading {output_name}")
        response = requests.get("http://212.183.159.230/1GB.zip", stream=True)
        total_bytes = response.headers.get('content-length')
        downloaded_bytes = 0
        bar_length = 20
        chunk_size = 16384
        start = time.time()
        timer = 0
        frame_length = 0.1
        
        if total_bytes is None: # no content length header
            f.write(response.content)
        else:
            with open(output_name, 'wb') as f:
                total_bytes = int(total_bytes)
                for chunk in response.iter_content(chunk_size):
                    downloaded_bytes += len(chunk)
                    time_elapsed = time.time()  - start
                    timer += time_elapsed
                    f.write(chunk)
                    progress = round((downloaded_bytes/total_bytes) * 100, 2)
                    bar_fill = int(bar_length * downloaded_bytes / int(total_bytes))
                    speed = (downloaded_bytes // time_elapsed) / 100000
                    bar_left = '*' * bar_fill
                    bar_right = ' ' * (bar_length - bar_fill)
                    if timer >= frame_length:
                        timer = 0
                        sys.stdout.write(f"\r {round(time_elapsed)} [{bar_left}{bar_right}] {round(progress)}% - {round(speed, 2)} Mbps\r\r")
                        sys.stdout.flush()

def main(){

    # load the yaml config file
    vm_config = read_yaml_file(vm_config_path)
    print(vm_config)

    # create a directory to hold the VM assets
    make_dir(vm_config['VM']['vm_name'], False, True)

    # download a cloud image
    # build the download url from base url, codename, image name, and filetype
    # Name and Type
    name = f"{vm_config['VM']['ubuntu_codename']}{vm_config['VM']['cloud_image_name']}{vm_config['VM']['cloud_image_filetype']}"
    url = f"{vm_config['VM']['cloud_image_url']}/{name}"

    download_file(url, name)
}

