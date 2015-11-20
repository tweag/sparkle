import java.io.IOException;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;

class HelloInvoke
{
    private native byte[] invokeHS(byte[] clos, int closLen, byte[] arg, int argLen);

    public static void main(String[] args)
    {
        String closFile = args[0];
        String argFile  = args[1];

        Path closPath = FileSystems.getDefault().getPath("", closFile);
        Path argPath = FileSystems.getDefault().getPath("", argFile);
        Path resultPath = FileSystems.getDefault().getPath("", "result.bin");

        try {
            byte[] clos = Files.readAllBytes(closPath);
            byte[] arg = Files.readAllBytes(argPath);

            byte[] res = new HelloInvoke().invokeHS(clos, clos.length, arg, arg.length);
            Files.write(resultPath, res);

        } catch (IOException e) {
            System.out.println(e);
        }
    }
    static {
        System.loadLibrary("HelloInvoke");
    }
}
