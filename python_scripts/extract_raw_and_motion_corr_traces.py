#!/usr/bin/env python
import logging
import glob
import os
import sys
import numpy as np
from tqdm import tqdm
import datetime
from scipy.io import loadmat, savemat
import caiman as cm
import argparse


def parse_input_from_command():
    """Read input argv, with default
    :return:
    """
    parser = argparse.ArgumentParser(description='Analyse brain data.')
    parser.add_argument('data_path', type=str, help='Full path to data folder (under 2p)')
    args = parser.parse_args(sys.argv[1:])
    return args.data_path


def create_dirs_if_missing(dirs_list):  # todo: should be common function
    for curr_dif in dirs_list:
        if not os.path.exists(curr_dif):
            os.makedirs(curr_dif)


def neuron_traces(rois, images):
    # rois is n_neurons x 2 (y,x), images is n_frames x Y x X
    result = np.zeros([rois.shape[0], images.shape[0]])
    result[:] = np.nan
    for ind in tqdm(range(rois.shape[0])):
        masked_pxls = images[:, rois[ind, 0].T.flatten(), rois[ind, 1].T.flatten()]  # shape: n_framex X n_pixels
        result[ind, :] = np.nanmean(masked_pxls, axis=1)
    return result


if __name__ == '__main__':
    if len(sys.argv) >= 1:  # argv[0] is script name. If any args given, use them
        data_path = parse_input_from_command()
    else:
        logging.error("Lacking input parameters. Run script with '-h' flag for options")
        sys.exit(1)

    # validate inputs
    found_files = glob.glob(os.path.join(data_path, "tiffs", '*_order_C_frames*.mmap'))
    if len(found_files) != 1:
        logging.error("Error. Can't find single tiff in {0}".format(
            os.path.join(data_path, "tiffs", '*_order_C_frames_*_.mmap'), len(found_files)))
        sys.exit(1)

    if not os.path.exists(os.path.join(data_path, "data.mat")):
        logging.error("Error. Can't find mat data file in {0}".format(
            os.path.join(data_path, "data.mat")))
        sys.exit(1)

    logging.info("Start analysis (time: {0})".format(datetime.datetime.now()))
    data = loadmat(os.path.join(data_path, "data.mat"))  # slow function

    logging.info("Found {0}. Loading".format(found_files[0]))
    m_motion_c = cm.load(found_files[0])  # shape (35000, 512, 1024), (frames, y, x)
    logging.info("Done reloading model (time: {0})".format(datetime.datetime.now()))

    motion_traces = neuron_traces(data['spatial'], m_motion_c)
    del m_motion_c  # free memory

    m_orig = cm.load(glob.glob(os.path.join(data_path, "tiffs", '*.tiff')))
    orig_traces = neuron_traces(data['spatial'], m_orig)
    del m_orig

    savemat(os.path.join(data_path, "neuron_traces.mat"),
            {'raw_traces': orig_traces, 'motion_traces': motion_traces, 'spatial': data['spatial'],
             'centers': data['centers']})
    logging.info("Done saving mat to {0}".format(os.path.join(data_path, "neuron_traces.mat")))

    logging.info("Done analysis (time: {0})".format(datetime.datetime.now()))
