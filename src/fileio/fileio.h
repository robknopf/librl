#ifndef FILEIO_H
#define FILEIO_H

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include "fileio_common.h"

int fileio_init(const char *mount_point);
void fileio_deinit(void);

/**
 * Writes data to a file, ensuring that directories in the path exist.
 *
 * @param filename The name of the file to write to.
 * @param data The data to write to the file.
 * @return 0 on success, or -1 on failure.
 */
// int fileio_write(const char *filename, const char *data);
int fileio_write(const char *filename, void *data, size_t size);

/**
 * Reads data from a file.
 *
 * @param filename The name of the file to read from.
 * @return A dynamically allocated buffer containing the file contents, or NULL on failure.
 *         The caller is responsible for freeing the returned buffer.
 */
fileio_read_result_t fileio_read(const char *filename);

fileio_read_result_t fileio_read_url(const char *host, const char *path, int timeout_ms);

/**
 * Checks if a file exists.
 *
 * @param filename The name of the file to check.
 * @return true if the file exists, false otherwise.
 */
bool fileio_exists(const char *filename);

/**
 * Creates directories recursively.
 *
 * @param path The directory path to create.
 * @return 0 on success, or -1 on failure.
 */
int fileio_mkdir(const char *path);

#endif // FILEIO_H
