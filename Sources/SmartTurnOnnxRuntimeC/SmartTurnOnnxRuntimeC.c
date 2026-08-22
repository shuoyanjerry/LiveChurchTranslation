#include "SmartTurnOnnxRuntimeInternal.h"

int32_t st_ort_create_session(
    const char *model_path,
    STOrtSession **out_session,
    char **out_error
) {
    if (out_session == NULL || model_path == NULL) {
        st_copy_error("Model path and output session are required.", out_error);
        return 2;
    }
    *out_session = NULL;
    const OrtApiBase *base = OrtGetApiBase();
    const OrtApi *api = base == NULL ? NULL : base->GetApi(ORT_API_VERSION);
    if (api == NULL) {
        st_copy_error("ONNX Runtime C API is unavailable.", out_error);
        return 1;
    }
    STOrtSession *runtime = calloc(1, sizeof(STOrtSession));
    if (runtime == NULL) {
        st_copy_error("Unable to allocate the ONNX Runtime session.", out_error);
        return 1;
    }
    runtime->api = api;
    OrtSessionOptions *options = NULL;
    OrtStatus *status = api->CreateEnv(
        ORT_LOGGING_LEVEL_WARNING,
        "SemanticEndpointSmartTurn",
        &runtime->environment
    );
    if (st_check_status(api, status, out_error) != 0) {
        st_release_partial(runtime);
        return 1;
    }
    status = api->CreateSessionOptions(&options);
    if (st_check_status(api, status, out_error) != 0) {
        goto create_failure;
    }
    status = api->SetSessionExecutionMode(options, ORT_SEQUENTIAL);
    if (st_check_status(api, status, out_error) != 0) {
        goto create_failure;
    }
    status = api->SetInterOpNumThreads(options, 1);
    if (st_check_status(api, status, out_error) != 0) {
        goto create_failure;
    }
    status = api->SetSessionGraphOptimizationLevel(options, ORT_ENABLE_ALL);
    if (st_check_status(api, status, out_error) != 0) {
        goto create_failure;
    }
    status = api->CreateSession(runtime->environment, model_path, options, &runtime->session);
    if (st_check_status(api, status, out_error) != 0) {
        goto create_failure;
    }
    api->ReleaseSessionOptions(options);
    status = api->CreateCpuMemoryInfo(
        OrtArenaAllocator,
        OrtMemTypeDefault,
        &runtime->memory_info
    );
    if (st_check_status(api, status, out_error) != 0) {
        st_release_partial(runtime);
        return 1;
    }
    *out_session = runtime;
    return 0;

create_failure:
    api->ReleaseSessionOptions(options);
    st_release_partial(runtime);
    return 1;
}

int32_t st_ort_predict(
    STOrtSession *runtime,
    float *features,
    size_t feature_count,
    float *out_probability,
    char **out_error
) {
    if (runtime == NULL || features == NULL || out_probability == NULL || feature_count != 64000) {
        st_copy_error("Expected exactly 64,000 float input features.", out_error);
        return 2;
    }
    const OrtApi *api = runtime->api;
    int64_t shape[] = {1, 80, 800};
    OrtValue *input = NULL;
    OrtValue *output = NULL;
    OrtStatus *status = api->CreateTensorWithDataAsOrtValue(
        runtime->memory_info,
        features,
        feature_count * sizeof(float),
        shape,
        3,
        ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
        &input
    );
    const char *input_names[] = {"input_features"};
    const char *output_names[] = {"logits"};
    const OrtValue *inputs[] = {input};
    if (st_check_status(api, status, out_error) != 0) {
        return 1;
    }
    status = api->Run(
        runtime->session,
        NULL,
        input_names,
        inputs,
        1,
        output_names,
        1,
        &output
    );
    if (st_check_status(api, status, out_error) != 0) {
        api->ReleaseValue(input);
        return 1;
    }
    void *output_data = NULL;
    status = api->GetTensorMutableData(output, &output_data);
    int32_t result = st_check_status(api, status, out_error);
    if (result == 0 && output_data != NULL) {
        *out_probability = *((float *)output_data);
    } else if (result == 0) {
        st_copy_error("ONNX Runtime returned no output data.", out_error);
        result = 1;
    }
    api->ReleaseValue(output);
    api->ReleaseValue(input);
    return result;
}

void st_ort_destroy_session(STOrtSession *session) {
    st_release_partial(session);
}

void st_ort_free_error(char *error_message) {
    free(error_message);
}

const char *st_ort_runtime_version(void) {
    const OrtApiBase *base = OrtGetApiBase();
    return base == NULL ? NULL : base->GetVersionString();
}
