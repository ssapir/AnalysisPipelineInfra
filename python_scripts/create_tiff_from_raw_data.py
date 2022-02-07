#!/usr/bin/env python
# coding: utf-8

import numpy as np
import os
import tifffile
import logging
import sys
import argparse


def get_metadata(metadata_path):  # function of Shai Tishby, needs refactoring to lxml parsing
    if not metadata_path.endswith('Experiment.xml'):
        logging.error('invalid path')
        sys.exit(1)
    
    with open(metadata_path, 'r') as file:
        metadata = file.read()

    xloc = metadata.find('pixelX=')
    pixelX = int(metadata[xloc + len('pixelX="'):metadata.find(' ', xloc) - 1])
    logging.info(f'pixelX = {pixelX}')
    yloc = metadata.find('pixelY=')
    pixelY = int(metadata[yloc + len('pixelY="'):metadata.find(' ', yloc) - 1])
    logging.info(f'pixelY = {pixelY}')
    pixelsizeloc = metadata.find('pixelSizeUM="', xloc)
    pixelsize = float(metadata[pixelsizeloc + len('pixelSizeUM="'):metadata.find(' ', pixelsizeloc) - 1])
    logging.info(f'pixelsize = {pixelsize} um')
    framesloc = metadata.find(' frames="')
    frames = int(metadata[framesloc + len(' frames="'):metadata.find(' ', framesloc + 1) - 1])
    logging.info(f'frames = {frames}')
    frloc = metadata.find('frameRate="')
    fr = float(metadata[frloc + len('frameRate="'):metadata.find(' ', frloc + 1) - 1])
    logging.info(f'frame rate = {fr}')
    return {'pixelX': pixelX, 'pixelY': pixelY, 'pixelsize': pixelsize, 'frames': frames, 'fr': fr}


def create_dirs_if_missing(dirs_list):
    for curr_dif in dirs_list:
        if not os.path.exists(curr_dif):
            os.makedirs(curr_dif)


def raw_to_tiff(data_path, metadata_path, rawfile_path, newname='data', frames_per_chunk=1000):  # adapted from function of Shai Tishby
    """Convert .raw file to .tiff files and save in the same location
    slice the data into chunks of 1000 frames (~1GB in size)

    :param data_path:
    :param metadata_path:
    :param rawfile_path:
    :param newname:
    :param frames_per_chunk:
    :return:
    """
    if not rawfile_path.endswith('.raw'):
        logging.error('invalid .raw file path')
        sys.exit(1)

    metadata = get_metadata(metadata_path)
    out_path = os.path.join(data_path, "tiffs")
    logging.info(out_path)
    create_dirs_if_missing([out_path])

    shape=(metadata['frames'], metadata['pixelY'], metadata['pixelX'])  # shape format is TXY
    data = np.memmap(rawfile_path, dtype='int16', shape=shape, mode='r')
    
    n_of_chunks = int(metadata['frames'] / 1000)
    chunks = data.reshape(n_of_chunks, frames_per_chunk, metadata['pixelY'], metadata['pixelX'])

    for i in range(n_of_chunks):
        tifffile.imwrite(os.path.join(out_path, newname + '_' + str(i + 1) + '.tiff'), chunks[i, :, :, :], imagej=True, 
                         metadata={'unit': 'um', 'finterval': 1./metadata['fr'], 'axes': 'TYX'}, photometric='minisblack')


def parse_input_from_command():
    """Read input argv, with default
    :return:
    """
    parser = argparse.ArgumentParser(description='Analyse brain data.')
    parser.add_argument('data_path', type=str, help='Full path to data folder (under 2p)')
    args = parser.parse_args(sys.argv[1:])
    return args.data_path


# run me with data path, and an optional fish name (for debug/parallel run purpose)
if __name__ == '__main__':
    if len(sys.argv) >= 1:  # argv[0] is script name. If any args given, use them
        data_path = parse_input_from_command()
    else:
        logging.error("Lacking input parameters. Run script with '-h' flag for options")
        sys.exit(1)

    metadata_path = os.path.join(data_path, "Experiment.xml")
    raw_path = os.path.join(data_path, "Image_001_001.raw")
    logging.info("Run tif conversion on {0} {1}".format(metadata_path, raw_path))
    raw_to_tiff(data_path, metadata_path, raw_path, 'name')
