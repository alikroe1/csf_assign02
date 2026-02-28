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

/* Computes row and column number for given pixel in photo
 * @param index index of pixel to calculate row number for
 * @param width width of image
 * @return row number of pixel
 * @return column number of pixel
 */
.globl getIndex
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

.globl getPixel
getPixel:
	/*
 	* Parameters:
	*   %rdi - pointer to input_img
	*   %esi - row index
	*   %edx - column index
	*   
	* Register use:
	*   %rax - get index of pixel
	*
	* Returns:
	*   %rax - pointer to input_img->data[row * input_img->width + col]
 	*/
	movl %esi, %eax
	imull 0(%rdi)
	addl %edx, %eax
	movq 8(%rdi), %rdx
	movl (%rdx, %eax, 4), %eax

.globl createAveragePixel
createAveragePixel:
	/*
 	* Parameters:
	*   %rdi - pointer to first pixel
	*   %rsi - pointer to second pixel
	*   
	* Register use:
	*   %rax - get index of pixel
	*
	* Returns:
	*   %rax - pointer to input_img->data[row * input_img->width + col]
 	*/

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
	/*
	 * Register use:
	 *   %r12d - total number of pixels by height * width
	 *   %r13 - pointer to input image data 
	 *   %r14 - pointer to output image data 
	 *   %r15d - loop index/current pixel
	 *
	 *   %eax - temp variable for current pixel value 
	 *   %r8d - red component 
	 *   %r9d - green component 
	 *   %r10d - blue component 
	 *   %r11d - alpha component 
	 */
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

	/*
	 *Register use:
	 *%r12 - pointer to input image struct
	 *%r13 - pointer to output image struct
	 *%r14d - blur_dist
	 *%r15d - rows (height)
	 *%ebx - cols (width)
	 *%r8d - i / k
	 *%r9d - j / l
	 *-20(%rbp) - PixelAverager struct
	 *-24(%rbp) - k
	 *-28(%rbp) - l
	 *-32(%rbp) - i
	 *-36(%rbp) - j
	 */
	.globl imgproc_blur
imgproc_blur:
	
	#initalize variables
	pushq %rbp
	movq %rsp, %rbp
	pushq %rbx
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	subq $40, %rsp

	#use our variables for our inputs
	movq %rdi, %r12 #r12 = input_img
	movq %rsi, %r13 #r13 = output_img
	movl %edx, %r14d #r14d = blur_dist

	#x and y of our image
	movl 4(%r12), %r15d
	movl (%r12), %ebx

	#intitalize for loop with i = 0 and j = 0
	movl $0, %r8d                
.Lfor_loop1:
	#until i >= the rows
	cmpl %r15d, %r8d      
	jge .Lblur_done        
	movl $0, %r9d

.Lfor_loop2:
	#until j >= cols
	cmpl %ebx, %r9d
	jge .Lfor_loop1_increment    

	#pixelAverage struct
	leaq -20(%rbp), %rdi
	call pa_init
	
	# save i and j on stack
	movl %r8d, -32(%rbp)
	movl %r9d, -36(%rbp)

	#set k = -blur_dist
	movl %r14d, %r8d
	negl %r8d

.Lfor_loop3:
	#iterate k from -blur_dist to blur_dist
	cmpl %r14d, %r8d
	jg .Lfor_loop3_done

	#set l = -blur_dist
	movl %r14d, %r9d
	negl %r9d

.Lfor_loop4:
	#iterate l from -blur_dist to blur_dist
	cmpl %r14d, %r9d
	jg .Lfor_loop3_increment

	#l and j save to stack
	movl %r8d, -24(%rbp)
	movl %r9d, -28(%rbp)

	#input img
	movq %r12, %rdi
	#i from stack
	movl -32(%rbp), %esi
	#i + k
	addl %r8d, %esi
	#j from stakck
	movl -36(%rbp), %edx
	#j + l
	addl %r9d, %edx

	#pixel average
	leaq -20(%rbp), %rcx

	#update current pixel to blurred one
	call pa_update_from_img

	#get k and l from stack
	movl -24(%rbp), %r8d
	movl -28(%rbp), %r9d

	#increment 
	incl %r9d
	jmp .Lfor_loop4

.Lfor_loop3_increment:
	# increment for next row(inner)
	incl %r8d
	jmp .Lfor_loop3

.Lfor_loop3_done:
	#i and j from stack
	movl -32(%rbp), %r8d
	movl -36(%rbp), %r9d

	#get avg pixel val
	leaq -20(%rbp), %rdi
	call pa_avg_pixel
	

	#get pos = i * cols + j
	movl %r8d, %edx
	imull %ebx, %edx
	addl %r9d, %edx

	#get and replace alpha for new blurred pixel
	movq 8(%r12), %rcx
	movl (%rcx,%rdx,4), %ecx

	#get OG alpha
	andl $0xFF, %ecx

	#replace blurred alpha with OG alpha
	andl $0xFFFFFF00, %eax
	orl %ecx, %eax

	#store output_img->data[pos]

	#get i * cols + j and store in pos
	movl %r8d, %edx
	imull %ebx, %edx
	addl %r9d, %edx
	movq 8(%r13), %rcx
	#store resulting pixel into data position
	movl %eax, (%rcx,%rdx,4)

	#increment 
	incl %r9d
	jmp .Lfor_loop2

.Lfor_loop1_increment:
	# increment for next outer row
	incl %r8d
	jmp .Lfor_loop1

	
.Lblur_done:
	#free memory
	addq $40, %rsp
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbx
	popq %rbp
	
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
		movl (%rsi), %r8d
		mull 4(%rsi), %r8d # %r8 = output_img->width * output_img->height
		cmpl %ecx, %r8d # %r8 ? %ecx
		jge .Lloop_expand_end

		pushq %rdi
		pushq %rsi
		movl %ecx, %edi
		movl (%rsi), %esi
		call getIndex
		movl %r8d, %ecx # r8d = row
		movl %r9d, %edx # r9d = column
		popq %rdi
		popq %rsi

		movl %r9d, %eax
		shrl $1, %eax
		addl $1, %eax
		cmpl (%rdi), %eax # col/2 + 1 ? input_img->width
		jge .Lright_edge
		jl .Lnot_right_edge

		.Lright_edge:
			movb $1, %r10b
			jmp .Lend_r_edge
		
		.Lnot_right_edge:
			movb $0, %r10b
			jmp .Lend_r_edge

		.Lend_r_edge

		movl %r8d, %eax
		shrl $1, %eax
		addl $1, %eax
		cmpl 4(%rdi), %eax # row/2 + 1 ? input_img->height
		jge .Lbottom_edge
		jl .Lnot_bottom_edge

		.Lbottom_edge:
			movb $1, %r11b
			jmp .Lend_b_edge

		.Lnot_bottom_edge:
			movb $0, %r11b
			jmp .Lend_b_edge

		.Lend_b_edge

		pushq %rsi
		movl %r8d, %esi
		shrl $1, %esi
		movl %r9d, %edx
		shrl $1, %edx
		call getPixel
		movl %eax, %r12d # r12d = pixel_original
		popq %rsi

		movl %r8d, %eax
		shrl $1, %eax
		cmpl %eax, $0 # row % 2 ? 0
		je .Lhandle_even_row
		jne .Lhandle_odd_row

		.Lhandle_even_row:
			movl %r9d, %eax
			shrl $1, %eax
			cmpl %eax, $0 # col % 2 ? 0
			je .Lhandle_even_pixels
			jne .Lhandle_even_row_odd_col
			
			.Lhandle_even_pixels:
				movl 8(%rsi), %r13 # r13 = output_img->data
				movl %r12d, (%r13, %ecx, 4)
				jmp .Lloop_expand
			.Lhandle_even_row_odd_col:
				cmpb $1, %r10b
				je .Lhandle_even_pixels
				
				pushq %rsi
				movl %r8d, %esi
				shrl $1, %esi
				movl %r9d, %edx
				shrl $1, %edx
				addl $1, %edx
				call getPixel
				movl %eax, %r13d # r13d = pixel_right
				popq %rsi


				jmp .Lloop_expand


		



	.Lloop_expand_end:

		

	ret

/*
vim:ft=gas:
*/
