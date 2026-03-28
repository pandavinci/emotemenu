using Vintagestory.API.Client;

namespace SimpleRM.utils
{
    public static class ResoultionAddon
    {
        public static void GetScreenResolution(this ICoreClientAPI capi, ref int x, ref int y)
        {
            x = capi.Render.FrameWidth;
            y = capi.Render.FrameHeight;
        }
    }
}
