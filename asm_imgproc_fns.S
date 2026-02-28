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

.globl rowIndex
rowIndex:
	/*
	 * Parameters:
	 *   %edi - index of pixel
	 *   %esi - width of image
	 *
	 * Returns:
	 *   %eax - row index (index / width)
 	*/

	movl %edi, %eax
	xorl  %edx, %edx
	divl %esi
	ret

.globl columnIndex
columnIndex:
	/*
	 * Parameters:
	 *   %edi - index of pixel
	 *   %esi - width of image
	 *
	 * Returns:
	 *   %eax - column index (index % width)
	 */
	movl %edi, %eax
	xorl  %edx, %edx
	divl %esi
	movl %edx, %eax
	ret

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
	movl %edx, %ecx
	imull 0(%rdi)
	addl %ecx, %eax
	movq 8(%rdi), %rdx
	movslq %eax, %rax
	movl (%rdx, %rax, 4), %eax
	ret

.globl getRed
getRed:
	movl %edi, %eax
	shrl $24, %eax
	ret

.globl getGreen
getGreen:
	movl %edi, %eax
	shrl $16, %eax
	andl $0xFF, %eax
	ret

.globl getBlue
getBlue:
	movl %edi, %eax
	shrl $8, %eax
	andl $0xFF, %eax
	ret

.globl getAlpha
getAlpha:
	movl %edi, %eax
	andl $0xFF, %eax
	ret

.globl createPixel
createPixel:
	/*
	 * Parameters:
	 *   %edi - red
	 *   %esi - green
	 *   %edx - blue
	 *   %ecx - alpha
	 *
	 * Register use:
	 *   %edi - local red
	 *   %esi - local green
	 *   %edx - local blue
	 *   %ecx - local alpha
	 *
	 * Returns:
	 *   %eax - final pixel
	 */
	# clean bits
	andl $0xFF, %edi
	andl $0xFF, %esi
	andl $0xFF, %edx
	andl $0xFF, %ecx
	#shift RGBA values
	shll $24, %edi
	shll $16, %esi
	shll $8,  %edx
	movl %edi, %eax
	# add values to make pixel
	orl  %esi, %eax
	orl  %edx, %eax
	orl  %ecx, %eax
	ret

.globl createAveragePixel
createAveragePixel:
	/*
	 * Parameters:
	 *   %edi - pixel 1
	 *   %esi - pixel 2
	 *
	 * Register use:
	 *   %r12d - pixel 1 (local copy)
	 *   %r13d - pixel 2 (local copy)
	 *   %r14d - avg_red
	 *   %r15d - avg_green
	 *   %ebx  - avg_blue
	 *   %eax  - intermediate
	 *   %ecx  - intermediate
	 *
	 * Returns:
	 *   %eax - average pixel
	 */
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	pushq %rbx

	movl %edi, %r12d
	movl %esi, %r13d

	#avg_red
	movl %r12d, %edi
	call getRed
	movl %eax, %ecx
	movl %r13d, %edi
	call getRed
	addl %ecx, %eax
	shrl $1, %eax
	movl %eax, %r14d
	
	#avg_green
	movl %r12d, %edi
	call getGreen
	movl %eax, %ecx
	movl %r13d, %edi
	call getGreen
	addl %ecx, %eax
	shrl $1, %eax
	movl %eax, %r15d

	#avg_blue
	movl %r12d, %edi
	call getBlue
	movl %eax, %ecx
	movl %r13d, %edi
	call getBlue
	addl %ecx, %eax
	shrl $1, %eax
	movl %eax, %ebx

	#avg_alpha
	movl %r12d, %edi
	call getAlpha
	movl %eax, %ecx
	movl %r13d, %edi
	call getAlpha
	addl %ecx, %eax
	shrl $1, %eax

	#createPixel
	movl %r14d, %edi
	movl %r15d, %esi
	movl %ebx, %edx
	movl %eax, %ecx
	call createPixel

	popq %rbx
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	ret

.globl quadAveragePixel
quadAveragePixel:
	/*
	 * Parameters:
	 *   %edi - pixel 1
	 *   %esi - pixel 2
	 *   %edx - pixel 3
	 *   %ecx - pixel 4
	 *
	 * Register use:
	 *   %r12d - pixel 1 (local copy)
	 *   %r13d - pixel 2 (local copy)
	 *   %r14d - pixel 3 (local copy)
	 *   %r15d - pixel 4 (local copy)
	 *   %ebx  - avg_blue
	 *   %eax  - intermediate
	 *   %ecx  - pixel sum
	 *   -8(%rbp)  - avg_red
	 *   -12(%rbp) - avg_blue
	 *
	 * Returns:
	 *   %eax - average pixel
	 */
	
	pushq %rbp
	movq  %rsp, %rbp
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	pushq %rbx
	subq  $8, %rsp

	# store local copies
	movl %edi, %r12d
	movl %esi, %r13d
	movl %edx, %r14d
	movl %ecx, %r15d

	# avg_red
	movl %r12d, %edi
	call getRed
	movl %eax, %ecx
	movl %r13d, %edi
	call getRed
	addl %eax, %ecx
	movl %r14d, %edi
	call getRed
	addl %eax, %ecx
	movl %r15d, %edi
	call getRed
	addl %eax, %ecx
	shrl $2, %ecx
	movl %ecx, -8(%rbp)

	# avg_green
	movl %r12d, %edi
	call getGreen
	movl %eax, %ecx
	movl %r13d, %edi
	call getGreen
	addl %eax, %ecx
	movl %r14d, %edi
	call getGreen
	addl %eax, %ecx
	movl %r15d, %edi
	call getGreen
	addl %eax, %ecx
	shrl $2, %ecx
	movl %ecx, -12(%rbp)

	# avg_blue
	movl %r12d, %edi
	call getBlue
	movl %eax, %ecx
	movl %r13d, %edi
	call getBlue
	addl %eax, %ecx
	movl %r14d, %edi
	call getBlue
	addl %eax, %ecx
	movl %r15d, %edi
	call getBlue
	addl %eax, %ecx
	shrl $2, %ecx
	movl %ecx, %ebx

	# avg_alpha
	movl %r12d, %edi
	call getAlpha
	movl %eax, %ecx
	movl %r13d, %edi
	call getAlpha
	addl %eax, %ecx
	movl %r14d, %edi
	call getAlpha
	addl %eax, %ecx
	movl %r15d, %edi
	call getAlpha
	addl %eax, %ecx
	shrl $2, %ecx

	# create pixel
	movl -8(%rbp), %edi
	movl -12(%rbp), %esi
	movl %ebx, %edx
	call createPixel

	addq  $8, %rsp
	popq %rbx
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbp
	ret

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
	subq $8, %rsp

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

	movl $0, %ecx #red
	movl $0, %ebp #green
	movl $0, (%rsp) #blue
	movl $0, 4(%rsp) #total

	#set k = -blur_dist
	movl %r14d, %edi
	negl %edi

.Lfor_loop3:
	#iterate k from -blur_dist to blur_dist
	cmpl %r14d, %edi
	jg .Lfor_loop3_done

	#set l = -blur_dist
	movl %r14d, %esi
	negl %esi

.Lfor_loop4:
	#iterate l from -blur_dist to blur_dist
	cmpl %r14d, %esi
	jg .Lfor_loop3_increment

	#currX = i + k
	movl %r8d, %edx
	addl %edi, %edx

	#border x check
	cmpl $0, %edx
	jl .Lskip_pixel
	cmpl %r15d, %edx
	jge .Lskip_pixel

	#currY = j + l
	movl %r9d, %eax
	addl %esi, %eax

	#border y pixel check
	cmpl $0, %eax
	jl .Lskip_pixel
	cmpl %ebx, %eax
	jge .Lskip_pixel
	
	#get current and get colors
	imull %ebx, %edx
	addl %eax, %edx
	movq 8(%r12), %rax
	movl (%rax,%rdx,4), %edx
	
	#get red and add
	movl %edx, %eax
	shrl $24, %eax
	andl $0xFF, %eax
	addl %eax, %ecx

	#get green and add
	movl %edx, %eax
	shrl $16, %eax
	andl $0xFF, %eax
	addl %eax, %ebp

	#get blue and add
	movl %edx, %eax
	shrl $8, %eax
	andl $0xFF, %eax
	addl %eax, (%rsp)

	#increment total
	incl 4(%rsp)


.Lskip_pixel:
	#increment l
	incl %esi
	jmp .Lfor_loop4
.Lfor_loop3_increment:
	# increment for next row(inner)
	incl %edi
	jmp .Lfor_loop3

.Lfor_loop3_done:
	#get pos = i * cols + j
	movl %r8d, %eax
	imull %ebx, %eax
	addl %r9d, %eax

	#save position to edi
	movl %eax, %edi   

	#get OG alpha from input pixel
	movq 8(%r12), %rax
	movl (%rax,%rdi,4), %eax
	andl $0xFF, %eax

	# esi = alpha
	movl %eax, %esi       

	#load total for division
	movl 4(%rsp), %r10d

	#avg red = red / total
	movl %ecx, %eax
	cdq
	idivl %r10d
	movl %eax, %r11d

	#avg green = green / total
	movl %ebp, %eax
	cdq
	idivl %r10d
	movl %eax, %ecx

	#avg blue = blue / total
	movl (%rsp), %eax
	cdq
	idivl %r10d

	#create new pixel with our new RGB and A
	shll $24, %r11d
	shll $16, %ecx
	shll $8, %eax
	orl %r11d, %ecx
	orl %eax, %ecx
	orl %esi, %ecx

	#store output_img->data[pos]

	#get i * cols + j and store in pos
	movl %r8d, %edx
	imull %ebx, %edx
	addl %r9d, %edx
	movl %ecx, %eax       
	movq 8(%r13), %rcx
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
	addq $8, %rsp
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

/*
 * void imgproc_expand(struct Image *input_img, struct Image *output_img)
 *
 * Registers:
 *   %rbx = input_img
 *   %r12 = output_img
 *   %r13 = i (loop counter, 0..width*height of output)
 *   %r14 = row
 *   %r15 = col
 *   %rbp = saved base pointer
 *
 * struct Image layout (assumed):
 *   +0:  int32_t width
 *   +4:  int32_t height
 *   +8:  uint32_t *data
 */

imgproc_expand:
    pushq   %rbp
    movq    %rsp, %rbp
    pushq   %rbx
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15
    subq    $8, %rsp            /* align stack to 16 bytes */

    movq    %rdi, %rbx          /* input_img */
    movq    %rsi, %r12          /* output_img */

    /* compute total pixels = output_img->width * output_img->height */
    movl    0(%r12), %eax       /* output_img->width */
    movl    4(%r12), %ecx       /* output_img->height */
    imull   %ecx, %eax
    movl    %eax, %r13d         /* total = width * height */

    xorl    %r13d, %r13d        /* i = 0 */

.loop_start:
    /* check i < output_img->width * output_img->height */
    movl    0(%r12), %eax
    movl    4(%r12), %ecx
    imull   %ecx, %eax
    cmpl    %eax, %r13d
    jge     .loop_end

    /* row = rowIndex(i, output_img->width) */
    movl    %r13d, %edi
    movl    0(%r12), %esi
    call    rowIndex
    movl    %eax, %r14d         /* row */

    /* col = columnIndex(i, output_img->width) */
    movl    %r13d, %edi
    movl    0(%r12), %esi
    call    columnIndex
    movl    %eax, %r15d         /* col */

    /* right_edge = (col/2 + 1 >= input_img->width) */
    movl    %r15d, %eax
    sarl    $1, %eax            /* col/2 */
    addl    $1, %eax            /* col/2 + 1 */
    cmpl    0(%rbx), %eax       /* compare with input_img->width */
    setge   %cl
    movzbl  %cl, %ecx
    movl    %ecx, -36(%rbp)     /* right_edge on stack (we use stack local) */
    /* actually store in a callee-saved spot — use stack */
    /* We'll use: -36(%rbp) = right_edge, -40(%rbp) = bottom_edge */
    /* -44(%rbp) = pixel_original */

    /* bottom_edge = (row/2 + 1 >= input_img->height) */
    movl    %r14d, %eax
    sarl    $1, %eax            /* row/2 */
    addl    $1, %eax            /* row/2 + 1 */
    cmpl    4(%rbx), %eax       /* compare with input_img->height */
    setge   %cl
    movzbl  %cl, %ecx
    movl    %ecx, -40(%rbp)     /* bottom_edge */

    /* pixel_original = getPixel(input_img, row/2, col/2) */
    movq    %rbx, %rdi
    movl    %r14d, %esi
    sarl    $1, %esi            /* row/2 */
    movl    %r15d, %edx
    sarl    $1, %edx            /* col/2 */
    call    getPixel
    movl    %eax, -44(%rbp)     /* pixel_original */

    /* if (row % 2 == 0 && col % 2 == 0) */
    movl    %r14d, %eax
    andl    $1, %eax
    jne     .not_even_even
    movl    %r15d, %eax
    andl    $1, %eax
    jne     .not_even_even

    /* output_img->data[i] = pixel_original */
    movq    8(%r12), %rax       /* output_img->data */
    movl    -44(%rbp), %ecx
    movl    %ecx, (%rax, %r13, 4)
    jmp     .loop_next

.not_even_even:
    /* if (col % 2 != 0 && row % 2 == 0) — odd col, even row */
    movl    %r15d, %eax
    andl    $1, %eax
    je      .not_odd_col_even_row
    movl    %r14d, %eax
    andl    $1, %eax
    jne     .not_odd_col_even_row

    /* if (right_edge) => output = pixel_original */
    cmpl    $0, -36(%rbp)
    je      .odd_col_not_right_edge

    movq    8(%r12), %rax
    movl    -44(%rbp), %ecx
    movl    %ecx, (%rax, %r13, 4)
    jmp     .loop_next

.odd_col_not_right_edge:
    /* pixel_right = getPixel(input_img, row/2, col/2 + 1) */
    movq    %rbx, %rdi
    movl    %r14d, %esi
    sarl    $1, %esi
    movl    %r15d, %edx
    sarl    $1, %edx
    addl    $1, %edx
    call    getPixel
    /* createAveragePixel(pixel_original, pixel_right) */
    movl    -44(%rbp), %edi
    movl    %eax, %esi
    call    createAveragePixel
    movq    8(%r12), %rcx
    movl    %eax, (%rcx, %r13, 4)
    jmp     .loop_next

.not_odd_col_even_row:
    /* if (row % 2 != 0 && col % 2 == 0) — odd row, even col */
    movl    %r14d, %eax
    andl    $1, %eax
    je      .not_odd_row_even_col
    movl    %r15d, %eax
    andl    $1, %eax
    jne     .not_odd_row_even_col

    /* if (bottom_edge) => output = pixel_original */
    cmpl    $0, -40(%rbp)
    je      .odd_row_not_bottom_edge

    movq    8(%r12), %rax
    movl    -44(%rbp), %ecx
    movl    %ecx, (%rax, %r13, 4)
    jmp     .loop_next

.odd_row_not_bottom_edge:
    /* pixel_below = getPixel(input_img, row/2 + 1, col/2) */
    movq    %rbx, %rdi
    movl    %r14d, %esi
    sarl    $1, %esi
    addl    $1, %esi
    movl    %r15d, %edx
    sarl    $1, %edx
    call    getPixel
    /* createAveragePixel(pixel_original, pixel_below) */
    movl    -44(%rbp), %edi
    movl    %eax, %esi
    call    createAveragePixel
    movq    8(%r12), %rcx
    movl    %eax, (%rcx, %r13, 4)
    jmp     .loop_next

.not_odd_row_even_col:
    /* both i and j are odd — diagonal case */
    /* if (!right_edge && !bottom_edge) — full quad average */
    cmpl    $0, -36(%rbp)
    jne     .check_right_edge_only
    cmpl    $0, -40(%rbp)
    jne     .check_right_edge_only

    /* pixel_right = getPixel(input_img, row/2, col/2 + 1) */
    movq    %rbx, %rdi
    movl    %r14d, %esi
    sarl    $1, %esi
    movl    %r15d, %edx
    sarl    $1, %edx
    addl    $1, %edx
    call    getPixel
    movl    %eax, -48(%rbp)     /* pixel_right */

    /* pixel_below = getPixel(input_img, row/2 + 1, col/2) */
    movq    %rbx, %rdi
    movl    %r14d, %esi
    sarl    $1, %esi
    addl    $1, %esi
    movl    %r15d, %edx
    sarl    $1, %edx
    call    getPixel
    movl    %eax, -52(%rbp)     /* pixel_below */

    /* pixel_diagonal = getPixel(input_img, row/2 + 1, col/2 + 1) */
    movq    %rbx, %rdi
    movl    %r14d, %esi
    sarl    $1, %esi
    addl    $1, %esi
    movl    %r15d, %edx
    sarl    $1, %edx
    addl    $1, %edx
    call    getPixel
    movl    %eax, -56(%rbp)     /* pixel_diagonal */

    /* quadAveragePixel(pixel_original, pixel_right, pixel_below, pixel_diagonal) */
    movl    -44(%rbp), %edi
    movl    -48(%rbp), %esi
    movl    -52(%rbp), %edx
    movl    -56(%rbp), %ecx
    call    quadAveragePixel
    movq    8(%r12), %rcx
    movl    %eax, (%rcx, %r13, 4)
    jmp     .loop_next

.check_right_edge_only:
    /* else if (!right_edge) — average with right neighbor */
    cmpl    $0, -36(%rbp)
    jne     .check_bottom_edge_only

    /* pixel_right = getPixel(input_img, row/2, col/2 + 1) */
    movq    %rbx, %rdi
    movl    %r14d, %esi
    sarl    $1, %esi
    movl    %r15d, %edx
    sarl    $1, %edx
    addl    $1, %edx
    call    getPixel
    movl    -44(%rbp), %edi
    movl    %eax, %esi
    call    createAveragePixel
    movq    8(%r12), %rcx
    movl    %eax, (%rcx, %r13, 4)
    jmp     .loop_next

.check_bottom_edge_only:
    /* else if (!bottom_edge) — average with below neighbor */
    cmpl    $0, -40(%rbp)
    jne     .corner_case

    /* pixel_below = getPixel(input_img, row/2 + 1, col/2) */
    movq    %rbx, %rdi
    movl    %r14d, %esi
    sarl    $1, %esi
    addl    $1, %esi
    movl    %r15d, %edx
    sarl    $1, %edx
    call    getPixel
    movl    -44(%rbp), %edi
    movl    %eax, %esi
    call    createAveragePixel
    movq    8(%r12), %rcx
    movl    %eax, (%rcx, %r13, 4)
    jmp     .loop_next

.corner_case:
    /* both edges — output = pixel_original */
    movq    8(%r12), %rax
    movl    -44(%rbp), %ecx
    movl    %ecx, (%rax, %r13, 4)

.loop_next:
    incl    %r13d
    jmp     .loop_start

.loop_end:
    addq    $8, %rsp
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    popq    %rbx
    popq    %rbp
    ret