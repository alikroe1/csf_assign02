/*
 * x86-64 assembly language implementations of functions
 */

	.section .text

/* Offsets of struct Image fields */
#define IMAGE_WIDTH_OFFSET   0
#define IMAGE_HEIGHT_OFFSET  4
#define IMAGE_DATA_OFFSET    8

/*
 * TODO: define your helper functions here.
 * Don't forget to use the .globl directive to make
 * them visible to the test code.
 */

/* Computes row number for given pixel in photo
 * @param index index of pixel to calculate row number for
 * @param width width of image
 * @return row number of pixel
 */
.globl rowIndex
getIndex:
	/*
 	* Parameters:
	*   %edi - index of pixel
	*   %esi - width of image
	*   
	* Register use:
	*   %eax - division calculation
	*
	* Returns:
	*   %eax - row index
	*   %edx - column index
 	*/

	movl %edi, %eax
	divl %esi

/*
 * Definitions of image transformation functions
 */

/*
 *  Transform the entire image by shrinking it down both 
 *  horizontally and vertically (by potentially different
 *  factors). This is equivalent to sampling the orignal image
 *  for every pixel that is in certain rows and columns as 
 *  specified in the function inputs.
 * 
 *  Take the image below where each letter corresponds to a pixel
 * 
 *                  XAAAYBBB
 *                  AAAABBBB
 *                  ZCCCWDDD
 *                  CCCCDDDD
 * 
 *  If the user specified to shrink it horazontally by a factor 
 *  of 4 and shrink it vertically by a factor of 2, you would 
 *  sample pixel that had a row index such that 
 * 
 *              row index % 2 = 0 
 * 
 *  and a column index such that
 * 
 *              column index % 4 = 0
 * 
 *  in the above example, this would mean pixels that are in 
 *  rows 0 and 2 with columns 0 and 4. 
 *  The resultant image is:
 * 
 *                  XY
 *                  ZW
 *  
 *  @param input_img pointer to the input Image
 *  @param output_img pointer to the output Image (in which the
 *                    transformed pixels should be stored)
 *  @param xfac factor to downsize the image horizontally; guaranteed to be positive
 *  @param yfac factor to downsize the image vertically; guaranteed to be positive
 */
	.globl imgproc_squash
imgproc_squash:

	/*
	* 
 	* Parameters:
	*   %rdi - pointer to input Image
	*   %rsi - pointer to output Image
	*   %edx - x_fac
	*   %ecx - y_fac
	*   
	* Register use:
 	*   %r12 - output pixel row (i)
 	*   %r13 - output pixel column (j)
 	*   %r14d - output image pixel index (out_w * i + j)
 	*   %r15d - input image pixel index (input_image->width * i * y_fac + j * x_fac)
 	*   %rbx - intermediary arithmetic value
	*   %eax - input_img pixel
 	*
 	*/
	
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	pushq %rbx

	movl $0, %r12d # %r12d = int i = 0
	.Louter_for_squash:
		cmpl 4(%rsi), %r12d # compare i ? out_h
		jge .Lend_outer_squash # if i >= h, jump to end_outer
		
		movl $0, %r13d # %r13d = int j = 0
		.Linner_for_squash:
			cmp (%rsi), %r13d # compare j ? out_w
			jge .Lend_inner_squash # if j >= out_w, jump to outer_for

			movl (%rsi), %r14d # %r14d = out_w
			imul %r12d, %r14d # %r14d = out_w * i
			addl %r13d, %r14d # %r14d = out_w * i + j
			
			movl (%rdi), %r15d # %r15d = input_image->width
			imul %r12d, %r15d # %r15d = input_image->width * i
			imul %ecx, %r15d # %r15d = input_image->width * i * y_fac
			movl %r13d, %ebx # %ebx = j
			imul %edx, %ebx # %ebx = j * x_fac
			addl %ebx, %r15d # %r15d = input_image->width * i * y_fac + j * x_fac
			
			movq 8(%rdi), %rbx # store input_img->data
			movl (%rbx,%r15,4), %eax # store input_img->data[src_row * input_img->width + src_col]
			movq 8(%rsi), %r15 # store output_img->data
			movl %eax, (%r15,%r14,4) # replace output_img->data[i * out_w + j]

			addl $1, %r13d # j++
			jmp .Linner_for_squash

			.Lend_inner_squash:
				addl $1, %r12d # i++
				jmp .Louter_for_squash
		
		.Lend_outer_squash:

			popq %rbx
			popq %r15
			popq %r14
			popq %r13
			popq %r12

			ret

/*
 *  Transform the color component values in each input pixel
 *  by applying a rotation on the values of the color components
 *  I.e. the old pixel's red component value will be used for
 *  the new pixel's green component value, the old pixel's green
 *  component value will be used new pixel's blue component value
 *  and the old pixel's blue component value will be used new 
 *  pixel's red component value. The alpha value should not change.
 *  For instance, if a pixel had the hex value 0xAABBCCDD, the 
 *  transformed pixel would become 0xCCAABBDD
 * 
 *  @param input_img pointer to the input Image
 *  @param output_img pointer to the output Image (in which the
 *                    transformed pixels should be stored)
 */
	.globl imgproc_color_rot
imgproc_color_rot:
	# similarly to our C function, find dimensions of image and iterate and change each pixel shifting colors
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15

	#get pixel height and width and store dimensions to eax
	movl (%rdi), %eax
	imull 4(%rdi), %eax

	#store picture dimensions into r12
	movl %eax, %r12d

	#find the data value and store into r13
	movq 8(%rdi), %r13

	#same for our image and output image 
	movq 8(%rsi), %r14
	

	#set the start of our loop to 0
	movl $0, %r15d

.Lclr_rot_loop:
	#set out loop iterate through every pixel
	cmpl %r12d, %r15d
	jge	.Lclr_rot_loop_done

	#for each pixel, store data (r13 = data of r15 value)
	movl (%r13, %r15, 4), %eax

	#get the rgb + alpha of each pixel
	movl %eax, %r8d
	shrl $24, %r8d          

	movl %eax, %r9d
	shrl $16, %r9d
	andl $0xFF, %r9d     

	movl %eax, %r10d
	shrl $8, %r10d
	andl $0xFF, %r10d    

	movl %eax, %r11d
	andl $0xFF, %r11d 

	#create new pixel based on the colors and shift accordingly
	shll $24, %r10d
	shll $16, %r8d  
	shll $8, %r9d 

	#now add the shifts to r10d
	orl %r8d, %r10d
	orl %r9d, %r10d
	orl %r11d, %r10d    

	#store this new data to r15, our output
	movl %r10d, (%r14, %r15, 4)   

	#increment for next pixel
	incl %r15d
	jmp .Lclr_rot_loop

.Lclr_rot_loop_done:
	#free memory of our variables
	popq %r15
	popq %r14
	popq %r13
	popq %r12

	ret


/*
 *  Transform the input image using a blur effect.
 * 
 *  Each pixel of the output image should have its color components
 *  determined by taking the average of the color components of pixels
 *  within blur_dist number of pixels horizontally and vertically from
 *  the pixel's location in the original image. For example, if
 *  blur_dist is 0, then only the original pixel is considered, and the
 *  the output image should be identical to the input image. If blur_dist
 *  is 1, then the original pixel and the 8 pixels immediately surrounding
 *  it would be considered, etc.  Pixels positions not within the bounds of
 *  the image should be ignored: i.e., their color components aren't
 *  considered in the computation of the result pixels.
 * 
 *  The alpha value each output pixel should be identical to the
 *  corresponding input pixel.
 * 
 *  Averages should be computed using purely integer arithmetic with
 *  no rounding.
 * 
 *  @param input_img pointer to the input Image
 *  @param output_img pointer to the output Image (in which the
 *                    transformed pixels should be stored)
 *  @param blur_dist all pixels whose x/y coordinates are within
 *                   this many pixels of the x/y coordinates of the
 *                   original pixel should be included in the color
 *                   component averages used to determine the color
 *                   components of the output pixel
 */
	.globl imgproc_blur
imgproc_blur:
	/* TODO: implement */
	ret

/*
 *  The `expand` transformation doubles the width and height of the image.
 *  
 *  Let's say that there are n rows and m columns of pixels in the
 *  input image, so there are 2n rows and 2m columns in the output
 *  image.  The pixel color and alpha value of the output pixel at row i and column
 *  j should be computed as follows.
 *  
 *  If both i and j are even, then the color and alpha value of the output
 *  pixel are exactly the same as the input pixel at row i/2 and column j/2.
 *  
 *  If i is even but j is odd, then the color components and alpha value
 *  of the output pixel are computed as the average of those in the input pixels
 *  in row i/2 at columns floor(j/2) and floor(j/2) + 1.
 *  
 *  If i is odd and j is even, then the color components and alpha value
 *  of the output pixel are computed as the average of those in the input pixels
 *  in column j/2 at rows floor(i/2) and  floor(i/2) + 1.
 *  
 *  If both i and j are odd then the color components and alpha value
 *  of the output pixel are computed as the average of the input pixels
 *  
 *  1. At row floor(i/2) and column floor(j/2)
 *  2. At row floor(i/2) and column floor(j/2) + 1
 *  3. At row floor(i/2) + 1 and column floor(j/2)
 *  4. At row floor(i/2) + 1 and column floor(j/2) + 1
 *  
 *  Note that in the cases where either i or j is odd, it is not
 *  necessarily the case that either row floor(i/2) + 1 or
 *  column floor(j/2) + 1 are in bounds in the input image.
 *  Only input pixels that are properly in bounds should be incorporated into
 *  the averages used to determine the color components and alpha value
 *  of the output pixel.
 *  
 *  Averages should be computed using purely integer arithmetic with
 *  no rounding.
 * 
 *  @param input_img pointer to the input Image
 *  @param output_img pointer to the output Image (in which the
 *                    transformed pixels should be stored)
 */
	.globl imgproc_expand
imgproc_expand:
	/*
	* 
 	* Parameters:
	*   %rdi - pointer to input Image
	*   %rsi - pointer to output Image
	*   
	* Register use:
 	*   %ecx - pixel iterator (i)
 	*   %r13 - output pixel column (j)
 	*   %r14d - output image pixel index (out_w * i + j)
 	*   %r15d - input image pixel index (input_image->width * i * y_fac + j * x_fac)
 	*   %rbx - intermediary arithmetic value
	*   %eax - input_img pixel
 	*
 	*/

	pushq %rcx

	movl $0, %ecx # ecx = i = 0
	.Lloop_expand:
		movl (%rsi), %r8
		mull 4(%rsi), %r8 # %r8 = output_img->width * output_img->height
		cmpl %ecx, %r8 # %r8 ? %ecx
		jge .Lloop_expand_end

		pushq %rcx
		pushq %rdx
		call getIndex
		movl %r8, %rcx # r8 = row
		movl %r9, %rdx # r9 = column
		popq %rdx
		popq %rcx

		

	.Lloop_expand_end:

		

	ret

/*
vim:ft=gas:
*/
