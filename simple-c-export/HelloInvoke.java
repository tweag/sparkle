class HelloInvoke
{
    private native void invokeC();
    public static void main(String[] args)
    {
        new HelloInvoke().invokeC();
    }
    static {
        System.loadLibrary("HelloInvoke");
    }
}
