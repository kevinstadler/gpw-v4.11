#!/bin/bash

#   0    5    0    .6   0  3
# R XXXXX          XXX       right shift by 7 & 11111000 = 248
# G      XXXXX        XXX    right shift by 2 & 11111000 = 248
# B           XXXXX      XXX left shift by 3

#   0    5    0    .6   0  3
# R XXXX        XXXX         right shift by 4 & 11110000 = 240
# G     XXXX        XXXX     & 11110000 = 240
# B         XXXX        XXXX left shift by 4

if [ ! -f "interleaved.tif" ]; then
  echo "Re-encoding data into 24 interleaved bits"
  # FIXME post-decimals?
#    --calc="bitwise_or(bitwise_and(248, right_shift(A.astype(int), 7)), bitwise_and(7, (8*A).astype(int)))" \
  gdal_calc.py --co="COMPRESS=LZW" --co="TFW=YES" --co PREDICTOR=2 --type=Byte --quiet \
    --calc="bitwise_or(bitwise_and(240, right_shift(A.astype(int), 4)), bitwise_and(15, (16*A).astype(int)))" \
    --outfile="PRE0-3POST0-3.tif" --NoDataValue=0 -A "gpw_v4_population_density_rev11_2020_30_sec.tif"
#    --calc="bitwise_or(bitwise_and(248, right_shift(A.astype(int), 2)), bitwise_and(7, (64*A).astype(int)))" \
  gdal_calc.py --co="COMPRESS=LZW" --co="TFW=YES" --co PREDICTOR=2 --type=Byte --quiet \
    --calc="bitwise_or(bitwise_and(240, A.astype(int)), bitwise_and(15, (256*A).astype(int)))" \
    --outfile="PRE4-7POST4-7.tif" --NoDataValue=0 -A "gpw_v4_population_density_rev11_2020_30_sec.tif"
#    --calc="bitwise_or(left_shift(A.astype(int), 3), bitwise_and(7, (512*A).astype(int)))" \
  gdal_calc.py --co="COMPRESS=LZW" --co="TFW=YES" --co PREDICTOR=2 --type=Byte --quiet \
    --calc="bitwise_or(left_shift(A.astype(int), 4), bitwise_and(15, (4096*A).astype(int)))" \
    --outfile="PRE8-11POST8-11.tif" --NoDataValue=0 -A "gpw_v4_population_density_rev11_2020_30_sec.tif"

  gdal_merge.py -co "COMPRESS=LZW" -co "TFW=YES" -co PREDICTOR=2 -ot Byte -separate -o "interleaved.tif" "PRE0-3POST0-3.tif" "PRE4-7POST4-7.tif" "PRE8-11POST8-11.tif"
fi

for PROFILE in "geodetic mercator"; do
  mkdir "$PROFILE"
  cd "$PROFILE"
  if [ ! -d "png" ]; then
    echo "Creating PNG tiles"
    # https://pypi.org/project/gdal2tiles/
    python3 <<< "import gdal2tiles
options = { 'profile': '$PROFILE', 's_srs': '+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs', 'tile_size': 512, 'zoom': (1, 7), 'kml': False, 'webviewer': 'none' }
gdal2tiles.generate_tiles('interleaved.tif', 'png/', **options)"
  fi

  cd "png"

  if [ ! -d "../j" ]; then
    echo "Creating JPG tiles"
    mogrify -format jpg             */*/*.png && rsync -rv --include '*/' --include '*.jpg' --exclude '*' --remove-source-files . ../j
  fi
  if [ ! -d "../j95" ]; then
    echo "Creating JPG 95 quality tiles"
    mogrify -format jpg -quality 95 */*/*.png && rsync -rv --include '*/' --include '*.jpg' --exclude '*' --remove-source-files . ../j95
  fi
#  if [ ! -d "../webp" ]; then
#    echo "Creating WebP tiles"
#    mogrify -format webp            */*/*.png && rsync -rv --include '*/' --include '*.webp' --exclude '*' --remove-source-files . ../webp
#  fi
  if [ ! -d "../webpl" ]; then
    echo "Creating lossless WebP tiles"
    mogrify -format webp -define webp:lossless=true */*/*.png && rsync -rv --include '*/' --include '*.webp' --exclude '*' --remove-source-files . ../webpl
  fi

  cd ../..
done
