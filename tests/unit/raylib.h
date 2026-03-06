#ifndef RAYLIB_H
#define RAYLIB_H

typedef unsigned char *(*LoadFileDataCallback)(const char *file_name, int *data_size);

void SetLoadFileDataCallback(LoadFileDataCallback callback);

#endif // RAYLIB_H
