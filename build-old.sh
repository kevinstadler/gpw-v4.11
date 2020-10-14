#!/bin/bash

if [ -z "$1" ]; then

#    "SPARSE_OK=TRUE"
  if [ ! -f "MSB.tif" ]; then
    # truncate 32 bit float at 65535 so that we can construct a 16 bit (+ 8 bit post-decimal) representation of it
#    gdal_translate -co "COMPRESS=LZW" -co "TFW=YES" -ot Byte -scale 256 65535 "gpw_v4_population_density_rev11_2020_30_sec.tif" "MSB.tif"
    # FIXME msb is still one too low, dunno why
    gdal_calc.py --co="COMPRESS=LZW" --co="TFW=YES" --type=Byte --calc="trunc(A/256)" --outfile="MSB.tif" --NoDataValue=0 -A "gpw_v4_population_density_rev11_2020_30_sec.tif"
  fi
  if [ ! -f "LSB.tif" ]; then
    gdal_calc.py --co="COMPRESS=LZW" --co="TFW=YES" --type=Byte --calc="trunc(mod(A,256.0))" --outfile="LSB.tif" --NoDataValue=0 -A "gpw_v4_population_density_rev11_2020_30_sec.tif"
#    gdal_translate -co "COMPRESS=LZW" -co "TFW=YES" -ot Byte -scale_2 0
  fi
  if [ ! -f "merged.tif" ]; then
    gdal_calc.py --co="COMPRESS=LZW" --co="TFW=YES" --type=Byte --calc="trunc(mod(A,1)*256)" --outfile="POST.tif" --NoDataValue=0 -A "gpw_v4_population_density_rev11_2020_30_sec.tif"
    gdal_merge.py -co "COMPRESS=LZW" -co "TFW=YES" -ot Byte -separate -o "merged.tif" "MSB.tif" "LSB.tif" "POST.tif"
  fi

  if [ -z "old strategies" ]; then
#  gdal_translate -co "COMPRESS=LZW" -co "TFW=YES" -ot UInt16 "gpw_v4_population_density_rev11_2020_30_sec.tif" "uint16.tif"

#  if [ ! -f "grayscale-alpha.tif" ]; then
    gdal_merge.py -co "COMPRESS=LZW" -co "TFW=YES" -ot Byte -separate -o "grayscale-alpha.tif" "MSB.tif" "LSB.tif"
    gdal_edit.py -colorinterp_2 alpha -a_nodata 0 "grayscale-alpha.tif"
  fi

  echo "Building tiles..."
#  PROFILE=raster # no resampling at zoom level 8 but messed up tile boundaries...
  PROFILE=geodetic
  # for this to produce 16 bit png grayscale pixels like so: https://lists.osgeo.org/pipermail/gdal-dev/2014-September/040111.html
  if [ ! -d "$PROFILE" ]; then
    # TODO use --tilesize=512 ?
    /usr/local/Cellar/gdal/2.4.4_2/bin/gdal2tiles.py --tilesize=512 --resume --exclude -w none --profile=$PROFILE --s_srs="+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs" --no-kml --verbose "merged.tif" "$PROFILE/"
  fi
  cd "$PROFILE"

#  mogrify -format jpg */*/*.png # -quality 85
#  rsync -rv --include '*/' --include '*.jpg' --exclude '*' --remove-source-files . ../j85

  # one more time interlaced
#  mogrify -format jpg -interlace plane */*/*.png # -quality 85
#  rsync -rv --include '*/' --include '*.jpg' --exclude '*' --remove-source-files . ../ji85

#  mogrify -format jpg -quality 90 */*/*.png
#  rsync -rv --include '*/' --include '*.jpg' --exclude '*' --remove-source-files . ../j90

#  mogrify -format jp2 -quality 0 */*/*.png
#  rsync -rv --include '*/' --include '*.jp2' --exclude '*' --remove-source-files . ../jpeg2000

  mogrify -format webp -define webp:lossless=true */*/*.png
  rsync -rv --include '*/' --include '*.webp' --exclude '*' --remove-source-files . ../webp

  # lossless with Google's cwebp -- same filesize as with imagemagick/mogrify
#  COMPDIR="webp"
#  for FILE in `ls */*/*.png`; do
#    if [ ! -d "../$COMPDIR/`dirname $FILE`" ]; then
#      mkdir -p "../$COMPDIR/`dirname $FILE`"
#    fi
#    echo "Creating `dirname $FILE`/`basename $FILE .png`.webp"
#    cwebp -z 9 $FILE -o "../$COMPDIR/`dirname $FILE`/`basename $FILE .png`.webp" # default is the faster -z 6
    # even 100% quality lossy webp compression leads to artefacts because of how values are spread across the 3 channels...
    #cwebp -q 100 $FILE -o "../$COMPDIR/`dirname $FILE`/`basename $FILE .png`.webp" # default is the faster -z 6
    #convert $FILE "../$COMPDIR/`dirname $FILE`/`basename $FILE .png`.jpg"
#  done

  #for DIR in `ls -d */*`; do
  #  mkdir -p "../$COMPDIR/$DIR"
  #done

#  gdal2mbtiles --resampling=bilinear --spatial-reference 4326 --format jpg "merged.tif" "$PROFILE.mbtiles"

  # DELETED=0
  # KEPT=0
  # for file in $PROFILE/7/*/*.png; do
  #   diff "$file" "emptytruecolor.png" > /dev/null
  #   if [ $? -eq 0 ]; then
  #     rm `dirname $file`/`basename $file png`*
  #     DELETED=$((DELETED + 1))
  #     echo "Deletion #$DELETED: ($file)"
  #   else
  #     KEPT=$((KEPT + 1))
  #     echo "Kept #$KEPT"
  #   fi
  # done

fi

exit 1

# OLD HARD-CODED TRANSFORMS

RANGE=255.0

if [ "$1" = "linear" ]; then
  CAP=400
  CALC="$RANGE * minimum(1, A/$CAP)"
  SETNAME="linear-$CAP"

# elif [ "$1" = "log" ]; then

# #  MAX=810693.5625
#   SETNAME=1000
#   MAXLOG=`echo "l($SCALEARG)" | bc -l`
#   # inspect in R: max=1000; curve(log(x+1) / log(max), 1, max, 1000)

#   # logarithmic transformation
#   CALC="$RANGE * log(A+1) / $MAXLOG"

else

  # logistic transformation: 1/(1+exp(-rate*(x-midpoint)))

  MIDPOINT=200 # midpoint of the logistic
  # midpoints between 200 and 400 are fine, next gotta find RATE which has 0.1 at 0 (and 0.9 at 2*midpoint)
  # lower headroom = steeper curve = faster transition = high-density regions saturate more quickly = less nuance
  HEADROOM=.2
#  1/.1 -1 = exp(rate*midpoint)
#  rate = log(1/headroom - 1) / midpoint
  # normalize by: minval = 1/(1+exp(rate*midpoint)) => normalized = (val - minval) / (1 - minval)
  RATE=`echo "l(1/$HEADROOM - 1) / $MIDPOINT" | bc -l`
  RATE=${RATE:0:4} # 3 decimal digits

  # inspect in R (WITH normalization):
  # midpoint = 200; sapply(c(.05, .1, .15, .2), function(headroom) { rate = log(1/headroom - 1) / midpoint; minval = 1/(1+exp(rate*midpoint)); curve((1/(1+exp(-rate*(x-midpoint))) - minval) / (1 - minval), 0, 4*midpoint, 4*midpoint+1, ylim=0:1, add = headroom!=.05, col=hsv(5*headroom)) })
  # midpoint = 300; sapply(c(.05, .1, .15, .2), function(headroom) { rate = log(1/headroom - 1) / midpoint; minval = 1/(1+exp(rate*midpoint)); curve((1/(1+exp(-rate*(x-midpoint))) - minval) / (1 - minval), 0, 4*midpoint, 4*midpoint+1, ylim=0:1, add = TRUE, col=hsv(5*headroom)) })

  # COMBOS:
  # 200/.2 => .004
  # 200/.1 => .01
  # 200/.05 => .014
  # 300/.1 => .007
  # 300/.05 => ?

  MINVAL=`echo "$RANGE/(1 + e($RATE * $MIDPOINT))" | bc -l`
  NORMALIZE=`echo "($RANGE - $MINVAL) / $RANGE" | bc -l` # (RANGE-MINVAL) / RANGE
  CALC="($RANGE/(1+exp(-$RATE*(A-$MIDPOINT))) - $MINVAL) / $NORMALIZE"
  SETNAME="logistic-$MIDPOINT-$RATE"

fi

if [ ! -f "$SETNAME-alpha.tif" ]; then
  echo "Applying $SETNAME transformation: $CALC"
  gdal_calc.py --quiet --calc="$CALC" --outfile=$SETNAME.tif --co="COMPRESS=LZW" --co="TFW=YES" --type=Byte --NoDataValue=0 --overwrite -A gpw_v4_population_density_rev11_2020_30_sec.tif || exit 1
  echo "Creating GeoTiff with alpha channel..."
  convert $SETNAME.tif -alpha copy $SETNAME-alpha.tif
  cp $SETNAME.tfw $SETNAME-alpha.tfw
fi

echo "Building tiles..."
PROFILE=geodetic
#PROFILE=raster  --zoom=1-7
/usr/local/Cellar/gdal/2.4.4_2/bin/gdal2tiles.py --resume --exclude --resampling=average -w none --profile=$PROFILE --s_srs="+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs" --no-kml --verbose "$SETNAME-alpha.tif" "$SETNAME/"
