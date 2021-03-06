// $Header: /u/drspeech/repos/quicknet2/QN_MLP_BunchCudaVar.h,v 1.3 2011/05/13 02:33:12 davidj Exp $

#ifndef QN_MLP_BunchCudaVar_H_INCLUDED
#define QN_MLP_BunchCudaVar_H_INCLUDED

#ifdef QN_CUDA

/* Must include the config.h file first */
#include <QN_config.h>
#include <stdio.h>
#include "QN_MLP.h"
#include "QN_MLP_BaseFl.h"
#include "QN_Logger.h"

// An MLP class that supports bunch mode, has a variable number
// of layers and works on CUDA hardware.  Must be compiled with nvcc.

// Workspace to pass to cuda code
// All variables here should only be modified in constructor/destructor.
// Stuff this points to can be modified at other times.
const size_t QN_MLP_MAX_WEIGHTS = QN_MLP_MAX_LAYERS - 1;
struct QN_BunchCudaVar_Workspace
{
    float *in;
    float *out;
    float *targ;

    float *layer_bias[QN_MLP_MAX_LAYERS]; // Biases
    float *weights[QN_MLP_MAX_WEIGHTS];   // Weights

    float *weights_delta[QN_MLP_MAX_WEIGHTS];	//cz277 - momentum
    float *l_bias_delta[QN_MLP_MAX_LAYERS];	//cz277 - revisit momentum

    float *layer_x[QN_MLP_MAX_LAYERS]; // Input to layer
    float *layer_y[QN_MLP_MAX_LAYERS]; // Output from layer
    float *layer_dedy[QN_MLP_MAX_LAYERS]; // Output error
    float *layer_dydx[QN_MLP_MAX_LAYERS]; // Output sigmoid difference
    float *layer_dedx[QN_MLP_MAX_LAYERS]; // Feed back error term from output
    float *layer_delta_bias[QN_MLP_MAX_LAYERS]; // Output bias update 

    float * cache_raw_last2_y;//cw564 - mbt
    float * cache_last2_weights; //cw564 - mbt

    float * cache_weights; //cw564 - mbt
    //cz277 - fast softmax
    float *compcache;
};

class QN_MLP_BunchCudaVar : public QN_MLP_BaseFl
{
public:
    QN_MLP_BunchCudaVar(int a_bp_num_layer,	//cz277 - nn fea bp
		      int a_debug, const char* a_dbgname,
		      size_t a_n_layers,
		      const size_t a_layer_units[QN_MLP_MAX_LAYERS],
		      enum QN_CriterionType a_criteriontype, enum QN_LayerType *a_layertype,     //cz277 - criteria      //cz277 - nonlinearity, mul actv
		      enum QN_OutputLayerType a_outtype, size_t a_size_bunch,
		      int device_no,	//cz277 - device select
		      const char *env_var4dev_id);	//cz277 - env var
    ~QN_MLP_BunchCudaVar();

    void forward(size_t n_frames, const float* in, float* out,
            const float * * wgt = NULL, const size_t num_basis = 1); //cw564
    void train(size_t n_frames, const float* in, const float* target,
            float* out, const float * * wgt = NULL, const size_t num_basis = 1); //cw564
  
    void set_weights(enum QN_SectionSelector which,
		     size_t row, size_t col,
		     size_t n_rows, size_t n_cols,
		     const float* weights);
    void get_weights(enum QN_SectionSelector which,
		     size_t row, size_t col,
		     size_t n_rows, size_t n_cols,
		     float* weights);

    virtual float * Last_y();
    virtual float * Last2_weights();

protected:
    // Forward pass one frame
    void forward_bunch(size_t n_frames, const float* in, float* out,
            const float * * spkr_wgt = NULL, const size_t num_basis = 1); //cw564 - mbt

    // Train one frame
    void train_bunch(size_t n_frames, const float* in, const float* target,
		     float* out,
                     const float * * spkr_wgt = NULL, const size_t num_basis = 1); //cw564 - mbt

private:
    void refresh_dev_weights(void);
    void refresh_host_weights(void);
    void devcheck(const char* location);
    void devnew(const char* varname, int n, int size, void **devptr);
    void devfree(const char* varname, const void* devptr);
    void devnew_vf(const char* varname, int n, float **devptr);
    void devnew_vi(const char* varname, int n, int **devptr);
    void devfree_vf(const char* varname, const float* devptr);
    void devfree_vi(const char* varname, const int* devptr);
    void todev_vf_vf(const char* varname, int n, const float* from,
		      float* devto);
    void fromdev_vf_vf(const char* varname, int n, const float* devfrom,
		       float* to);
    void todev_vi_vi(const char* varname, int n, const int* from,
		      int* devto);
    void fromdev_vi_vi(const char* varname, int n, const int* devfrom,
		       int* to);

    const enum QN_CriterionType criterion_type; //cz277 - criteria
    const enum QN_LayerType *hiddenlayer_types;   //cz277 - nonlinearity, mul actv

    const enum QN_OutputLayerType out_layer_type; // Type of output layer
						  // (e.g. sigmoid, softmax).

    /* float *layer_x[MAX_LAYERS]; // Sum into layer (hid_x). */
    /* float *layer_y[MAX_LAYERS]; // Output from non linearity (hid_y). */

    /* float *layer_dedy[MAX_LAYERS]; // Output error. */
    /* float *layer_dydx[MAX_LAYERS]; // Output sigmoid difference. */
    /* float *layer_dedx[MAX_LAYERS]; // Feed back error term from output. */
    /* float *layer_delta_bias[MAX_LAYERS]; // Output bias update value for whole */
    /* 					 // bunch. */

    QN_BunchCudaVar_Workspace dev; // host version of workspace
    QN_BunchCudaVar_Workspace *ws; // device version of workspace

    int dev_weights_stale;	// True if host weights updated and
				// they need to be copied to device
    int host_weights_stale;	// Tue if device weights update
				// and they need to be copied to device

    static const int blocks_per_grid = 1;  // 
    static const int threads_per_block = 1;

    enum { checking = 0};	// Unless changed, not checking each CUDA op.

    //cz277 - nn fea bp
    int bp_num_layer;

};




#endif // #ifdef QN_CUDA

#endif // #define QN_MLP_BunchCudaVar_H_INLCUDED

