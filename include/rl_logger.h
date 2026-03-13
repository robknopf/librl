#ifndef RL_LOGGER_H
#define RL_LOGGER_H

#include "logger/log.h" // IWYU pragma: export

#ifdef __cplusplus
extern "C" {
#endif

void rl_logger_set_level(int level);

#ifdef __cplusplus
}
#endif

#endif // RL_LOGGER_H
