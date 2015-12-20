public class HaskellRTS
{
  static {
      System.out.println("Loading libHaskellRTS...");
      System.loadLibrary("HaskellRTS");
      hask_init();
      System.out.println("Haskell RTS is up");
  }

  public static
    native byte[] invokeHS(byte[] clos, int closLen, byte[] arg, int argLen);

  private static native void hask_init();
  private static native void hask_end();
}
