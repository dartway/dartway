/// Where there is no file system (node), goldens are compared, never
/// refreshed: the environment cannot ask for a refresh.
bool get goldenUpdateRequested => false;

void writeGolden(String path, String content) =>
    throw UnsupportedError('Goldens are refreshed on the VM.');
