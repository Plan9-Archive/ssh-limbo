# requests
SSH_FXP_INIT,
SSH_FXP_VERSION,
SSH_FXP_OPEN,
SSH_FXP_CLOSE,
SSH_FXP_READ,
SSH_FXP_WRITE,
SSH_FXP_LSTAT,
SSH_FXP_FSTAT,
SSH_FXP_SETSTAT,
SSH_FXP_FSETSTAT,
SSH_FXP_OPENDIR,
SSH_FXP_READDIR,
SSH_FXP_REMOVE,
SSH_FXP_MKDIR,
SSH_FXP_RMDIR,
SSH_FXP_REALPATH,
SSH_FXP_STAT,
SSH_FXP_RENAME,
SSH_FXP_READLINK,
SSH_FXP_SYMLINK: con 1+iota;

# responses
SSH_FXP_STATUS,
SSH_FXP_HANDLE,
SSH_FXP_DATA,
SSH_FXP_NAME,
SSH_FXP_ATTRS: con 101+iota;

SSH_FXP_EXTENDED,
SSH_FXP_EXTENDED_REPLY: con 201+iota;

# attribute flags
SSH_FILEXFER_ATTR_SIZE,
SSH_FILEXFER_ATTR_UIDGID,
SSH_FILEXFER_ATTR_PERMISSIONS,
SSH_FILEXFER_ATTR_ACMODTIME:	con 1<<iota;
SSH_FILEXFER_ATTR_EXTENDED:	con 16r80000000;

# open flags
SSH_FXF_READ,
SSH_FXF_WRITE,
SSH_FXF_APPEND,
SSH_FXF_CREAT,
SSH_FXF_TRUNC,
SSH_FXF_EXCL,
SSH_FXF_TEXT:	con 1<<iota;

SSH_FILEXFER_TYPE_REGULAR,
SSH_FILEXFER_TYPE_DIRECTORY,
SSH_FILEXFER_TYPE_SYMLINK,
SSH_FILEXFER_TYPE_SPECIAL,
SSH_FILEXFER_TYPE_UNKNOWN:	con 1+iota;

# status code
SSH_FX_OK,
SSH_FX_EOF,
SSH_FX_NO_SUCH_FILE,
SSH_FX_PERMISSION_DENIED,
SSH_FX_FAILURE,
SSH_FX_BAD_MESSAGE,
SSH_FX_NO_CONNECTION,
SSH_FX_CONNECTION_LOST,
SSH_FX_OP_UNSUPPORTED,
SSH_FX_INVALID_HANDLE,
SSH_FX_NO_SUCH_PATH,
SSH_FX_FILE_ALREADY_EXISTS,
SSH_FX_WRITE_PROTECT: con iota;
