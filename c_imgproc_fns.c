// C implementations of image processing functions

#include <stdlib.h>
#include <assert.h>
#include "imgproc.h"

//! Computes row number for given pixel in photo
//! @param index index of pixel to calculate row number for
//! @param width width of image
//! @return row number of pixel
int rowIndex(int index, int width) {
  return index / width;
}

//! Computes column number for given pixel in photo
//! @param index index of pixel to calculate row number for
//! @param width width of image
//! @return column number of pixel
int columnIndex(int index, int width) {
  return index % width;
}

//! Returns pixel data at given row and column
//! @param *input_img pointer to image containing pixel
//! @param row row index of desired pixel
//! @param col column index of desired pixel
//! @return desired pixel
uint32_t getPixel( struct Image *input_img, int row, int col) {
  return input_img->data[row * input_img->width + col];
}

//! Returns pixel's alpha data
//! @param pixel pixel whose alpha data we are trying to extract
//! @return pixel's alpha data
uint32_t getAlpha(uint32_t pixel) {
  return pixel & 0xFF;
}

//! Returns pixel's blue data
//! @param pixel pixel whose alpha data we are trying to extract
//! @return pixel's blue data
uint32_t getBlue(uint32_t pixel) {
  return (pixel >> 8) & 0xFF;
}

//! Returns pixel's green data
//! @param pixel pixel whose alpha data we are trying to extract
//! @return pixel's green data
uint32_t getGreen(uint32_t pixel) {
  return (pixel >> 16) & 0xFF;
}

//! Returns pixel's red data
//! @param pixel pixel whose alpha data we are trying to extract
//! @return pixel's red data
uint32_t getRed(uint32_t pixel) {
  return (pixel >> 24) & 0xFF;
}

//! creates new pixel with given RGBA values
//! @param red pixel's red value
//! @param green pixel's green value
//! @param blue pixel's blue value
//! @param alpha pixel's alpha value
//! @return new pixel with given RGBA values
uint32_t createPixel(uint32_t red, uint32_t green, uint32_t blue, uint32_t alpha) {
  return (red << 24) | (green << 16) | (blue << 8) | alpha;
}

//! creates new pixel whose RGBA values are an average of the 2 input pixels
//! @param pixel_one first pixel to average
//! @param pixel_two second pixel to average
//! @return new average pixel
uint32_t createAveragePixel(uint32_t pixel_one, uint32_t pixel_two) {
  uint32_t avg_red = (getRed(pixel_one) + getRed(pixel_two)) / 2;
  uint32_t avg_green = (getGreen(pixel_one) + getGreen(pixel_two)) / 2;
  uint32_t avg_blue = (getBlue(pixel_one) + getBlue(pixel_two)) / 2;
  uint32_t avg_alpha = (getAlpha(pixel_one) + getAlpha(pixel_two)) / 2;

  return createPixel(avg_red, avg_green, avg_blue, avg_alpha);
}

//! creates new pixel whose RGBA values are an average of the 4 input pixels
//! @param pixel_one first pixel to average
//! @param pixel_two second pixel to average
//! @param pixel_three third pixel to average
//! @param pixel_four fourth pixel to average
//! @return new average pixel
uint32_t quadAveragePixel(uint32_t pixel_one, uint32_t pixel_two, uint32_t pixel_three, uint32_t pixel_four) {
  uint32_t avg_red = (getRed(pixel_one) + getRed(pixel_two) + getRed(pixel_three) + getRed(pixel_four)) / 4;
  uint32_t avg_green = (getGreen(pixel_one) + getGreen(pixel_two) + getGreen(pixel_three) + getGreen(pixel_four)) / 4;
  uint32_t avg_blue = (getBlue(pixel_one) + getBlue(pixel_two) + getBlue(pixel_three) + getBlue(pixel_four)) / 4;
  uint32_t avg_alpha = (getAlpha(pixel_one) + getAlpha(pixel_two) + getAlpha(pixel_three) + getAlpha(pixel_four)) / 4;

  return createPixel(avg_red, avg_green, avg_blue, avg_alpha);
}

void pa_init( struct PixelAverager *pa ) {
  pa->r = 0;
  pa->g = 0;
  pa->b = 0;
  pa->a = 0;
  pa->count = 0;
}

void pa_update( struct PixelAverager *pa, uint32_t pixel ) {
  pa->r += getRed(pixel);
  pa->g += getGreen(pixel);
  pa->b += getBlue(pixel);
  pa->a += getAlpha(pixel);
  pa->count++;
}

void pa_update_from_img( struct Image *img, int32_t row, int32_t col, struct PixelAverager *pa ) {
  if (row < 0 || row >= img->height || col < 0 || col >= img->width) return;
  pa_update(pa, img->data[row * img->width + col]);
}

uint32_t pa_avg_pixel( struct PixelAverager *pa ) {
  return createPixel(pa->r / pa->count, pa->g / pa->count, pa->b / pa->count, pa->a / pa->count);
}

//! Transform the entire image by shrinking it down both 
//! horizontally and vertically (by potentially different
//! factors). This is equivalent to sampling the orignal image
//! for every pixel that is in certain rows and columns as 
//! specified in the function inputs.
//!
//! Take the image below where each letter corresponds to a pixel
//!
//!                 XAAAYBBB
//!                 AAAABBBB
//!                 ZCCCWDDD
//!                 CCCCDDDD
//!
//! If the user specified to shrink it horazontally by a factor 
//! of 4 and shrink it vertically by a factor of 2, you would 
//! sample pixel that had a row index such that 
//!
//!             row index % 2 = 0 
//!
//! and a column index such that
//!
//!             column index % 4 = 0
//!
//! in the above example, this would mean pixels that are in 
//! rows 0 and 2 with columns 0 and 4. 
//! The resultant image is:
//!
//!                 XY
//!                 ZW
//! 
//! @param input_img pointer to the input Image
//! @param output_img pointer to the output Image (in which the
//!                   transformed pixels should be stored)
//! @param xfac factor to downsize the image horizontally; guaranteed to be positive
//! @param yfac factor to downsize the image vertically; guaranteed to be positive
void imgproc_squash( struct Image *input_img, struct Image *output_img, int32_t xfac, int32_t yfac ) {
  
  // get width and height for image output
  int out_w = output_img->width;
  int out_h = output_img->height;
  
  // go through each pixel and choose to add the necessary pixels to the output image
  for (int i = 0; i < out_h; i++) {
    for (int j = 0; j < out_w; j++) {
      int src_row = i * yfac;
      int src_col = j * xfac;
      output_img->data[i * out_w + j] = input_img->data[src_row * input_img->width + src_col];
    }
  }
}

//! Transform the color component values in each input pixel
//! by applying a rotation on the values of the color components
//! I.e. the old pixel's red component value will be used for
//! the new pixel's green component value, the old pixel's green
//! component value will be used new pixel's blue component value
//! and the old pixel's blue component value will be used new 
//! pixel's red component value. The alpha value should not change.
//! For instance, if a pixel had the hex value 0xAABBCCDD, the 
//! transformed pixel would become 0xCCAABBDD
//!
//! @param input_img pointer to the input Image
//! @param output_img pointer to the output Image (in which the
//!                   transformed pixels should be stored)
void imgproc_color_rot( struct Image *input_img, struct Image *output_img) {
  
  // go through each pixel and shift RGB values
  for (int i = 0; i < input_img->width * input_img->height; i++) {
    uint32_t my_pixel = input_img->data[i];
    output_img->data[i] = createPixel(getBlue(my_pixel), getRed(my_pixel), getGreen(my_pixel), getAlpha(my_pixel));
  }
}

//! Transform the input image using a blur effect.
//!
//! Each pixel of the output image should have its color components
//! determined by taking the average of the color components of pixels
//! within blur_dist number of pixels horizontally and vertically from
//! the pixel's location in the original image. For example, if
//! blur_dist is 0, then only the original pixel is considered, and the
//! the output image should be identical to the input image. If blur_dist
//! is 1, then the original pixel and the 8 pixels immediately surrounding
//! it would be considered, etc.  Pixels positions not within the bounds of
//! the image should be ignored: i.e., their color components aren't
//! considered in the computation of the result pixels.
//!
//! The alpha value each output pixel should be identical to the
//! corresponding input pixel.
//!
//! Averages should be computed using purely integer arithmetic with
//! no rounding.
//!
//! @param input_img pointer to the input Image
//! @param output_img pointer to the output Image (in which the
//!                   transformed pixels should be stored)
//! @param blur_dist all pixels whose x/y coordinates are within
//!                  this many pixels of the x/y coordinates of the
//!                  original pixel should be included in the color
//!                  component averages used to determine the color
//!                  components of the output pixel
void imgproc_blur( struct Image *input_img, struct Image *output_img, int32_t blur_dist ) {
  
  // get row and column numbers
  int rows = input_img->height;
  int cols = input_img->width;
  
  //for all pixels...
  for (int i = 0; i < rows; i++) {
    for (int j = 0; j < cols; j++) {
      int red = 0;
      int green = 0;
      int blue = 0;
      int total = 0;

      //scan the suround pixels of said pixel
      for (int k = -blur_dist; k <= blur_dist; k++) {
        for (int l = -blur_dist; l <= blur_dist; l++) {
          int currX = i + k;
          int currY = j + l;

          //for pixels that are next to border, discard
          if (currX >= 0 && currX < rows && currY >= 0 && currY < cols) {

            uint32_t pixel = input_img->data[currX * cols + currY];
            red += (pixel >> 24) & 0xFF;
            green += (pixel >> 16) & 0xFF;
            blue += (pixel >> 8) & 0xFF;
            total++;
          }
        }
      }
      int pos = i * cols + j;
      //avg
      uint32_t alpha = input_img->data[pos] & 0xFF;
      uint32_t r = red / total;
      uint32_t g = green / total;
      uint32_t b = blue / total;

      output_img->data[pos] = (r << 24)|(g << 16)|(b << 8)|alpha;
    }
  }
}

//! The `expand` transformation doubles the width and height of the image.
//! 
//! Let's say that there are n rows and m columns of pixels in the
//! input image, so there are 2n rows and 2m columns in the output
//! image.  The pixel color and alpha value of the output pixel at row i and column
//! j should be computed as follows.
//! 
//! If both i and j are even, then the color and alpha value of the output
//! pixel are exactly the same as the input pixel at row i/2 and column j/2.
//! 
//! If i is even but j is odd, then the color components and alpha value
//! of the output pixel are computed as the average of those in the input pixels
//! in row i/2 at columns floor(j/2) and floor(j/2) + 1.
//! 
//! If i is odd and j is even, then the color components and alpha value
//! of the output pixel are computed as the average of those in the input pixels
//! in column j/2 at rows floor(i/2) and  floor(i/2) + 1.
//! 
//! If both i and j are odd then the color components and alpha value
//! of the output pixel are computed as the average of the input pixels
//! 
//! 1. At row floor(i/2) and column floor(j/2)
//! 2. At row floor(i/2) and column floor(j/2) + 1
//! 3. At row floor(i/2) + 1 and column floor(j/2)
//! 4. At row floor(i/2) + 1 and column floor(j/2) + 1
//! 
//! Note that in the cases where either i or j is odd, it is not
//! necessarily the case that either row floor(i/2) + 1 or
//! column floor(j/2) + 1 are in bounds in the input image.
//! Only input pixels that are properly in bounds should be incorporated into
//! the averages used to determine the color components and alpha value
//! of the output pixel.
//! 
//! Averages should be computed using purely integer arithmetic with
//! no rounding.
//!
//! @param input_img pointer to the input Image
//! @param output_img pointer to the output Image (in which the
//!                   transformed pixels should be stored)
void imgproc_expand( struct Image *input_img, struct Image *output_img) {
  
  // go through each pixel in the output image and handle it properly
  for (int i = 0; i < output_img->width * output_img->height; i++) {
    
    // get row and column indexes
    int row = rowIndex(i, output_img->width);
    int col = columnIndex(i, output_img->width);

    // figure out if the pixel is an edge
    int right_edge = col/2 + 1 >= input_img->width;
    int bottom_edge = row/2 + 1 >= input_img->height;

    // extract top left pixel
    uint32_t pixel_original = getPixel(input_img, row/2, col/2);

    // handle even pixels
    if (row % 2 == 0 && col % 2 == 0) {
      output_img->data[i] = pixel_original;
      continue;
    }

    // handle odd columns but even rows
    if (col % 2 != 0 && row % 2 == 0) {
      // handle right edges
      if (right_edge) {
        output_img->data[i] = pixel_original;
      }
      // handle regular pixels
      else {
        uint32_t pixel_right = getPixel(input_img, row/2, col/2 + 1);
        output_img->data[i] = createAveragePixel(pixel_original, pixel_right);
      }
      continue;
    }

    // handle even columns but odd rows
    if (row % 2 != 0 && col % 2 == 0) {
      // handle edges
      if (bottom_edge) {
        output_img->data[i] = pixel_original;
      } 
      // handle regular pixels
      else {
        uint32_t pixel_below = getPixel(input_img, row/2 + 1, col/2);
        output_img->data[i] = createAveragePixel(pixel_original, pixel_below);
      }
      continue;
    }

    // handle diagonal pixels
    if (!right_edge && !bottom_edge) {
      // calculate pixel values on all sides of diagonal pixels
      uint32_t pixel_right = getPixel(input_img, row/2, col/2 + 1);
      uint32_t pixel_below = getPixel(input_img, row/2 + 1, col/2);
      uint32_t pixel_diagonal = getPixel(input_img, row/2 + 1, col/2 + 1);
      output_img->data[i] = quadAveragePixel(pixel_original, pixel_right, pixel_below, pixel_diagonal);
    } 
    // handle non-side-edges
    else if (!right_edge) {
      uint32_t pixel_right = getPixel(input_img, row/2, col/2 + 1);
      output_img->data[i] = createAveragePixel(pixel_original, pixel_right);
    } 
    // handle non-bottom0edges
    else if (!bottom_edge) {
      uint32_t pixel_below = getPixel(input_img, row/2 + 1, col/2);
      output_img->data[i] = createAveragePixel(pixel_original, pixel_below);
    } 
    // handle bottom corner case
    else {
      output_img->data[i] = pixel_original;
    }
  }
}