const char* QN_cuvec_rcsid =
    "$Header: /u/drspeech/repos/quicknet2/QN_cuvec.cu,v 1.1 2011/03/10 00:27:57 davidj Exp $";

/* Must include the config.h file first */
#include <QN_config.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "QN_types.h"
#include "QN_cuvec.h"

#include <cuda.h>
#include <cublas.h>


__global__ void
qn_devnv_copy_vf_vf(size_t len, const float* from, float* to)
{
    size_t i;

    for (i=len; i!=0; i--)
	*to++ = *from++;
}

__global__ void
qn_devnv_sub_vfvf_vf(size_t n,
		     const float *in_vec1, const float *in_vec2,
		     float *res_vec)
{
    size_t i;
    for (i=n; i!=0; i--)
        (*res_vec++) = *(in_vec1++) - (*in_vec2++);
}

__global__ void
qn_devnv_mul_vfvf_vf(size_t n,
		     const float *in_vec1, const float *in_vec2,
		     float *res_vec)
{
    size_t i;
    for (i=n; i!=0; i--)
        (*res_vec++) = (*in_vec1++) * (*in_vec2++);
}

__global__ void
qn_devnv_mulacc_vff_vf(size_t n, const float *in, float scale, float *acc)
{
    size_t i;

    for (i=n; i!=0; i--)
        (*acc++) += scale * (*in++);
}

__global__ void
qn_devnv_dsigmoid_vf_vf(size_t n, const float* in_vec, float* out_vec)
{
    size_t i;

    for (i=n; i!=0; i--)
    {
        const float y = *in_vec++;

	*out_vec++ = (1.0f - y) * y;
    }
}


__global__ void
qn_devnv_sigmoid_vf_vf(int n, const float* in_vec, float* out_vec)
{
    size_t i;

    for (i=0; i<n; i++)
    {
	*out_vec++ = qn_devin_sigmoid_f_f(*in_vec++);
    }
}

__global__ void
qn_kern_sub_vfvf_vf(int n, const float* in_vec1, const float* in_vec2,
		      float* out_vec)
{
    int i = (blockIdx.x * blockDim.x) + threadIdx.x;

    if (i<n)
	out_vec[i] = in_vec1[i] - in_vec2[i];
}

__global__ void
qn_kern_mul_vfvf_vf(int n, const float* in_vec1, const float* in_vec2,
		      float* out_vec)
{
    int i = (blockIdx.x * blockDim.x) + threadIdx.x;

    if (i<n)
	out_vec[i] = in_vec1[i] * in_vec2[i];
}

__global__ void
qn_kern_sigmoid_vf_vf(int n, const float* in_vec, float* out_vec)
{
    int i = (blockIdx.x * blockDim.x) + threadIdx.x;

    if (i<n)
	out_vec[i] = 1.0f/(1.0f + __expf(-in_vec[i]));
}

__global__ void
qn_kern_tanh_vf_vf(int n, const float* in_vec, float* out_vec)
{
    int i = (blockIdx.x * blockDim.x) + threadIdx.x;

    if (i<n)
	out_vec[i] = tanh(in_vec[i]);
}


__global__ void
qn_kern_dsigmoid_vf_vf(int n, const float* in_vec, float* out_vec)
{
    int i = (blockIdx.x * blockDim.x) + threadIdx.x;

    if (i<n)
    {
	const float y = in_vec[i];
	out_vec[i] = (1.0f - y) * y;
    }
}

__global__ void
qn_kern_dtanh_vf_vf(int n, const float* in_vec, float* out_vec)
{
    int i = (blockIdx.x * blockDim.x) + threadIdx.x;

    if (i<n)
    {
	const float y = in_vec[i];
	out_vec[i] = (1.0f - y) * (1.0f + y);
    }
}

//cz277 - criteria, in_vec1 = y_i, in_vec2 = t_i
__global__ void
qn_kern_dxentropy_vf_vf(size_t n, const float* in_vec1, const float* in_vec2, float* out_vec)
{
    int i = (blockIdx.x * blockDim.x) + threadIdx.x;
    if (i < n)
    {
        float yi = in_vec1[i];
        if (yi == 0)
            yi = QN_MinProb;
	out_vec[i] = - in_vec2[i] / yi;
	//out_vec[i] = in_vec2[i];
    }
}

//cz277 - nonlinearity
__global__ void
qn_kern_dsoftmax_vf_vf(size_t n, const float* in_vec, float* out_vec)
{
    int i = (blockIdx.x * blockDim.x) + threadIdx.x;
    if (i < n)
    {
	const float yi = in_vec[i];
	out_vec[i] = (1 - yi) * yi;
    }
}

//cz277 - nonlinearity, x > 0 -> y > 0; x = 0 -> y = 0; x < 0 -> y < 0;
__global__ void
qn_kern_dsoftsign_vf_vf(size_t n, const float* in_vec, float* out_vec)
{
    int i = (blockIdx.x * blockDim.x) + threadIdx.x;
    if (i < n)
    {
	float temp;
	const float yi = in_vec[i];
	if (yi > 0)
	    temp = yi - 1;
	else
	    temp = yi + 1;
	out_vec[i] = temp * temp;
    }
}

//cz277 - nonlinearity
__global__ void
qn_kern_softsign_vf_vf(size_t n, const float* in_vec, float* out_vec)
{
    int i = (blockIdx.x * blockDim.x) + threadIdx.x;
    if (i < n)
    {
	out_vec[i] = in_vec[i] / (1 + abs(in_vec[i]));
    }
}

__global__ void
qn_kern_copy_vf_mf(int mat_height, int vec_len,
		   const float*vec, float* mat)
{
    int col = (blockIdx.x * blockDim.x) + threadIdx.x;

    if (col<vec_len)
    {
	int j;
	float val = vec[col];
	float* top = &mat[col];
	for (j=mat_height; j!=0; j--)
	{
	    *top = val;
	    top += vec_len;
	}
    }
}

//cz277 - fast softmax
__global__ void
qn_kern_fastcopy_vf_mf(int mat_height, int vec_len,
                   const float*vec, float* mat, int matsize)
{
    int matidx = (blockIdx.x * blockDim.x) + threadIdx.x;

    if (matidx < matsize)
    {
        int vecidx = matidx % vec_len; 
        float val = vec[vecidx];
	float *ptr = &mat[matidx];
	*ptr = val;
    }
}

// Kernel to sum columns in a matrix
// Do each column sum in its own thread
__global__ void
qn_kern_sumcol_mf_vf(int rows, int cols,
		     const float* in, float* res)
{
    int col = (blockIdx.x * blockDim.x) + threadIdx.x;

    if (col < cols)
    {
	int j;
	const float* fromp = &in[col];
	float* top = &res[col];
	
	(*top) = (*fromp);
	fromp+=cols;
	for (j=rows-1; j!=0; j--)
	{
	    (*top) += (*fromp);
	    fromp+=cols;
	}
    }
}

//cz277 - fast softmax
__global__ void
qn_kern_sumrow_vf_f(int rows, int cols, const float* in, float* res)
{
    int row = (blockIdx.x * blockDim.x) + threadIdx.x;

    if (row < rows)
    {
	int off = row * cols;
    	const float *inptr = &in[off];
	float *outptr = &res[off];
	float sum = 0.0;
	for (int i = 0; i != cols; ++i)
	{
	    sum += (*inptr);
	    ++inptr;
	}
	(*outptr) = 1.0f / sum;
    }
}

__global__ void
qn_kern_maxrow_vf_f(int rows, int cols, const float* in, float* res)
{
    int row = (blockIdx.x * blockDim.x) + threadIdx.x;

    if (row < rows)
    {
        int off = row * cols;
        const float *inptr = &in[off];
	float *outptr = &res[off];
        float max = *inptr;
	++inptr; 
        for (int i = 1; i != cols; ++i)
        {
            if ((*inptr) > max) {
		max = (*inptr);
	    }
	    ++inptr;
        }
        (*outptr) = max;
    }
}

//cz277 - fast softmax
__global__ void 
qn_kern_dualmax_ff_f(int cols, int size, int incr, const float *in_vec, float *out_vec)
{
    int absidx = (blockIdx.x * blockDim.x) + threadIdx.x;
    if (absidx < size)
    {
	int row = absidx / cols;
	int off = row * cols;
	int index = absidx - off;
	int den = 2 * incr;
	float *outptr = &out_vec[absidx];
	const float *inptr = &in_vec[absidx];
	if (index % den == 0)
	{
	    float lhval = (*inptr);
	    if (index + incr >= cols)
	    {
		*outptr = lhval;
	    } 
	    else
	    {
		inptr += incr;
            	float rhval = (*inptr);
	        if (lhval < rhval)
		{
		    *outptr = rhval;
		}
	    	else 
	    	{
		    *outptr = lhval;
	    	}
	    }
	}
    }
}

//cz277 - fast softmax
__global__ void
qn_kern_exp_f_f(int rows, int cols, int size, const float* in_vec, const float *comp_cache, float* out_vec)
{
    int index = (blockIdx.x * blockDim.x) + threadIdx.x;

    if (index < size)
    {
	int row = index / cols;
	int off = row * cols;
	float *outptr = &out_vec[index];
	const float *inptr = &in_vec[index];
	const float *compptr = &comp_cache[off];
    	(*outptr) = exp((*inptr) - (*compptr));
    }
}

//cz277 - fast softmax
__global__ void
qn_kern_scale_f_f(int rows, int cols, int size, const float* in, const float *cache, float* res)
{
    int index = (blockIdx.x * blockDim.x) + threadIdx.x;
    if (index < size)
    {
    	int row = index / cols;
    	int off = row * cols;
	float *outptr = &res[index];
	const float *compptr = &cache[off];
	const float *inptr = &in[index];
    	(*outptr) = (*compptr) * (*inptr);
    }
}

//cz277 - fast softmax
__global__ void
qn_kern_div_f_f(int rows, int cols, int size, const float* in, const float *cache, float* res)
{
    int index = (blockIdx.x * blockDim.x) + threadIdx.x;
    if (index < size)
    {
        int row = index / cols;
        int off = row * cols;
        float *outptr = &res[index];
        const float *compptr = &cache[off];
        const float *inptr = &in[index];
        (*outptr) = (*inptr) / (*compptr);
    }
}

//cz277 - fast softmax
__global__ void
qn_kern_tempsoftmax_mf_mf(int rows, int cols, float* in_vec, float* out_vec)
{
    int row = (blockIdx.x * blockDim.x) + threadIdx.x;
    if (row < rows)
    {
        int i;
        const int index = row * cols;
        float* invec = &in_vec[index];
        float* outvec = &out_vec[index];
        float* inptr;
        float* outptr;

        // Now put exp(in-max) in out
        inptr = invec;
        //outptr = outvec;
        float sumexp = 0;
        for (i=cols; i!=0; i--)
        {
	    sumexp += (*inptr);
	    ++inptr;
        }
        // Now scale the output
        float scale = 1.0f/sumexp;
        outptr = outvec;
	*outptr = scale;

	/*inptr = invec;	
        for (i=cols; i!=0; i--)
        {
	    *inptr = (*inptr) * scale;
	    ++inptr;
        }*/
    }
}

//cz277 - fast softmax
//cz277 - fast softmax
__global__ void
qn_kern_dualsum_ff_f(int cols, int size, int incr, const float *in_vec, float *out_vec)
{
    int absidx = (blockIdx.x * blockDim.x) + threadIdx.x;
    if (absidx < size)
    {
        int row = absidx / cols;
        int off = row * cols;
        int index = absidx - off;
	int den = 2 * incr;
        float *outptr = &out_vec[absidx];
        const float *inptr = &in_vec[absidx];
        if (index % den == 0)
        {
            float lhval = (*inptr);
            if (index + incr >= cols)
            {
                *outptr = lhval;
            }
            else
            {
                inptr += incr;
                //float rhval = (*inptr);
                *outptr = lhval + (*inptr);
            }
        }
    }
}


// Kernel for multisoftmax - several softmaxes at once
// Do each softmax row in its own thread
__global__ void
qn_kern_multisoftmax_mf_mf(int rows, int cols, const float* in_vec,
			   float* out_vec)
{
    int row = (blockIdx.x * blockDim.x) + threadIdx.x;
    if (row < rows)
    {
	int i;
	const int index = row * cols;
	const float* invec = &in_vec[index];
        float* outvec = &out_vec[index];
	const float* inptr;
	float* outptr;

	// First find the max of each vector
	float max;
	
	inptr = invec;
	max = *inptr++;
	for (i=cols-1; i!=0; i--)
	{
	    float val;

	    val = *inptr++;
	    if (val>max)
		max = val;
	}
	// Now put exp(in-max) in out
	inptr = invec;
	outptr = outvec;
	float sumexp = 0;
	for (i=cols; i!=0; i--)
	{
	    float f, e;
	    
	    f = *inptr++;
	    e = expf(f - max);
	    *outptr++ = e;
	    sumexp += e;
	}
	// Now scale the output
	float scale = 1.0f/sumexp;
	outptr = outvec;
	for (i=cols; i!=0; i--)
	{
	    *outptr = (*outptr) * scale;
	    outptr++;
	}
    }
}

__global__ void
qn_devnv_softmax_vf_vf(int n, const float* in_vec, float* out_vec)
{
    float max;
    float min;
    float sumexp = 0.0f;	/* Sum of exponents */
    float scale;		/* 1/sum of exponents */
    size_t i;

    qn_devin_maxmin_vf_ff(n, in_vec, &max, &min);	/* Find constant bias. */
    for (i=0; i<n; i++)
    {
	float f;		/* Input value. */
	float e;		/* Exponent of current value. */

	f = in_vec[i];
	e = expf(f - max);
	out_vec[i] = e;
	sumexp += e;
    }
    scale = 1.0f/sumexp;
    for (i=0; i<n; i++)
    {
	out_vec[i] = out_vec[i] * scale;
    }
}

__global__ void
qn_devnv_copy_vf_mf(size_t mat_height, size_t vec_len, const float* vec,
		    float* mat)
{
    size_t i, j;

    const float* vec_ptr;
    float* mat_ptr = mat;

    for (i=mat_height; i!=0; i--)
    {
	vec_ptr = vec;
	for (j=vec_len; j!=0; j--)
	{
	    (*mat_ptr++) = (*vec_ptr++);
	}
    }
}

__global__ void
qn_devnv_sumcol_mf_vf(size_t rows, size_t cols, const float* in, float* res)
{
    const float *const res_end_b8p = res + (cols & ~7);
    const float *const res_end_p = res + cols;
    float* res_p;
    const float* in_p = in;
    size_t i;

    /* Initialize the result */
    res_p = res;
    while(res_p != res_end_b8p)
    {
	res_p[0] = in_p[0];
	res_p[1] = in_p[1];
	res_p[2] = in_p[2];
	res_p[3] = in_p[3];
	res_p[4] = in_p[4];
	res_p[5] = in_p[5];
	res_p[6] = in_p[6];
	res_p[7] = in_p[7];
	res_p += 8;
	in_p += 8;
    }
    while (res_p != res_end_p)
    {
	(*res_p++) = (*in_p++);
    }
    /* The main loop */
    for (i=1; i!=rows; i++)
    {
	res_p = res;
	while(res_p != res_end_b8p)
	{
	    res_p[0] += in_p[0];
	    res_p[1] += in_p[1];
	    res_p[2] += in_p[2];
	    res_p[3] += in_p[3];
	    res_p[4] += in_p[4];
	    res_p[5] += in_p[5];
	    res_p[6] += in_p[6];
	    res_p[7] += in_p[7];
	    res_p += 8;
	    in_p += 8;
	}
	while (res_p != res_end_p)
	{
	    (*res_p++) += (*in_p++);
	}
    }
}


__global__ void
qn_devnv_mul_mfmf_mf(size_t Sm,size_t Sk,size_t Sn,
		  const float *A,const float *B,float *C)
{
  size_t i,j,k;
  for (i=0;i<Sm;i++)
  {
      for (j=0;j<Sn;j++)
      {
	  C[i*Sn+j] = 0.0f;
	  for (k=0;k<Sk;k++)
	      C[i*Sn+j] += A[i*Sk+k]*B[k*Sn+j];
      }
  }
}

__global__ void
qn_devnv_mulntacc_mfmf_mf(size_t Sm,size_t Sk,size_t Sn,
			  const float *A,const float *B,float *C)
{
  size_t i,j,k;
  for (i=0;i<Sm;i++)
    for (j=0;j<Sn;j++)
      for (k=0;k<Sk;k++)
        C[i*Sn+j] += A[i*Sk+k]*B[j*Sk+k];
}


__global__ void
qn_devnv_multnacc_fmfmf_mf(size_t Sk,size_t Sm,size_t Sn, float scale,
			   const float *A,const float *B,float *C)
{
    size_t i,j,k;
    float acc;

    for (i=0;i<Sm;i++)
    {
	for (j=0;j<Sn;j++)
	{
	    acc = 0.0f;
	    for (k=0;k<Sk;k++)
		acc += A[k*Sm+i]*B[k*Sn+j];
	    C[i*Sn+j] += acc * scale;
	}
    }
}

//cz277 - momentum
__global__ void
qn_kern_selfadd_vfvf_vf(int n, const float* in_vec1, float* in_vec2)
{
    int i = (blockIdx.x * blockDim.x) + threadIdx.x;
    if (i < n)
        in_vec2[i] += in_vec1[i];
}




