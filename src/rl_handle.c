#include "rl_handle.h"

#include "internal/exports.h"
#include "internal/rl_handle_pool.h"

RL_KEEP
rl_handle_type_t rl_handle_get_type(rl_handle_t handle)
{
    if (handle == 0) {
        return RL_TYPE_NONE;
    }
    return (rl_handle_type_t)RL_HANDLE_TYPE(handle);
}
