## gpw-v4.11 population density tiles

TMS raster tiles of the [Gridded Population of the World](https://sedac.ciesin.columbia.edu/data/set/gpw-v4-population-density-rev11) 30 arc-second population *density* dataset for 2020, created using the [gdal2tiles Python library](https://github.com/tehamalab/gdal2tiles).

> Center for International Earth Science Information Network - CIESIN - Columbia University. 2018. Gridded Population of the World, Version 4 (GPWv4): Population Density, Revision 11. Palisades, NY: NASA Socioeconomic Data and Applications Center (SEDAC). https://doi.org/10.7927/H49C6VHW. Accessed 15 Oct 2020.

The purpose of the tiles is to be used in the [imagined communities](https://thiswasyouridea.com/imagined-communities/) web map project, so the original floating point GTiff data is transformed into traditional image formats as described below.

### numerical transformation

[In an earlier dataset](/kevinstadler/gpw-tiles/), population density was both truncated and rounded from its original floating-point maximum of 55189 inhabitants/km² down to the byte-resolution \[0,255\] range. While this leads to significant loss of information about population density in urban cores, the data still captures the visually more relevant progression from uninhabited over rural to urban (see histograms below as well as Figure 4 in [this article](http://www.newgeography.com/content/004349-from-jurisdictional-functional-analysis-urban-cores-suburbs)). While the 8-bit grayscale PNGs produced by this approach led to small file sizes, it also locked the visual use of the tiles to a strictly linear scaling of the \[0,255\] range.

The present tileset preserves more numeric information from the gpw dataset by re-encoding it across the RGB channels of image files, which can then be reconstructed and manipulated by the tile rendering engine (e.g. using openlayers' [RasterSource](https://openlayers.org/en/latest/apidoc/module-ol_source_Raster-RasterSource.html)). A first approach rounded and truncated the population density information into 16 pre-comma bits (written into the red and green channels) and 8 post-comma bits (written into the blue channel). This encoding is easy to reconstruct by the rendering engine, but not a great idea because compression algorithms will alter the least significant bits of each channel equally, so even the slightest compression to the red channel is gonna throw off the population density by steps of 512. The best option to allow compressed tile forats would be to interleave the significant bits across all 3 channels, so that the 3 most significant digits of the 24 bit encoding would take the 1st position in the red, green and blue channels respectively. Because this representation is a bit cumbersome to reconstitute using bitwise operations, the current representation simply puts two non-interleaved blocks, one of 4 pre-comma digits and one of 4 post-comma digits, into the same color channel, resulting in truncation at a maximum value of 4096, and post-comma resolution of 1/4096th.

>             1     1   2   2
>   0    5    0.2   6   0   3
> R XXXX        XXXX         right shift by 4 & 11110000 (= 240)
> G     XXXX        XXXX                      & 11110000 (= 240)
> B         XXXX        XXXX left shift by 4
