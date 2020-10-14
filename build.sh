#!/bin/bash

#   0    5    0    .6   0  3
# R XXXXX          XXX       right shift by 7 & 11111000 = 248
# G      XXXXX        XXX    right shift by 2 & 11111000 = 248
# B           XXXXX      XXX left shift by 3

if [ ! -f "interleaved.tif" ]; then
  # FIXME post-decimals?
  gdal_calc.py --co="COMPRESS=LZW" --co="TFW=YES" --type=Byte \
    --calc="bitwise_or(bitwise_and(248, right_shift(A.astype(int), 7)), bitwise_and(7, (8*A).astype(int)))" \
    --outfile="PRE0-4POST0-2.tif" --NoDataValue=0 -A "gpw_v4_population_density_rev11_2020_30_sec.tif"
  gdal_calc.py --co="COMPRESS=LZW" --co="TFW=YES" --type=Byte \
    --calc="bitwise_or(bitwise_and(248, right_shift(A.astype(int), 2)), bitwise_and(7, (64*A).astype(int)))" \
    --outfile="PRE5-9POST3-5.tif" --NoDataValue=0 -A "gpw_v4_population_density_rev11_2020_30_sec.tif"
  gdal_calc.py --co="COMPRESS=LZW" --co="TFW=YES" --type=Byte \
    --calc="bitwise_or(left_shift(A.astype(int), 3), bitwise_and(7, (512*A).astype(int)))" \
    --outfile="PRE10-14POST6-8.tif" --NoDataValue=0 -A "gpw_v4_population_density_rev11_2020_30_sec.tif"

  gdal_merge.py -co "COMPRESS=LZW" -co "TFW=YES" -ot Byte -separate -o "interleaved.tif" "PRE0-4POST0-2.tif" "PRE5-9POST3-5.tif" "PRE10-14POST6-8.tif"
fi

# https://pypi.org/project/gdal2tiles/

#import gdal2tiles
#options = { 'profile': 'geodetic', 's_srs': 'TODO', 'tile_size': 512, 'kml': False, 'webviewer': 'none' }
#gdal2tiles.generate_tiles('interleaved.tif', '/path/to/output_dir/', **options)
