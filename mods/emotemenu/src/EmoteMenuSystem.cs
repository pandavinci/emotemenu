using System;
using Vintagestory.API.Client;
using Vintagestory.API.Common;
using emotemenu.helper;
using SimpleRM;

namespace emotemenu
{
    public class EmoteMenuSystem : ModSystem, IRenderer
    {
        private static readonly string HOTKEY_CODE = "emotemenu-open";
        private static readonly string CONFIG_FILE_NAME = "emotemenu.json";

        private bool disposed = false;
        private ICoreClientAPI capi;
        private LangConfigFile lang;
        private EMConfig config;
        private RadialMenu menu;

        public double RenderOrder => 1.0;
        public int RenderRange => 1;

        public override double ExecuteOrder()
        {
            return 0.2;
        }

        public override void StartClientSide(ICoreClientAPI api)
        {
            this.capi = api;
            this.LoadTranslations();
            this.ReloadConfig();
            this.InitEmoteMenu();
            this.RegisterHotkey();
            this.RegisterEvents();
        }

        private void RegisterHotkey()
        {
            this.capi.Input.RegisterHotKey(
                HOTKEY_CODE,
                this.lang.emote_properties_KeyBindDescription,
                GlKeys.BracketRight,
                HotkeyType.GUIOrOtherControls
            );
            
            this.capi.Input.SetHotKeyHandler(HOTKEY_CODE, OnHotkeyPressed);
            this.capi.Logger.Notification("[EmoteMenu] Hotkey registered: " + HOTKEY_CODE);
        }

        private void RegisterEvents()
        {
            this.capi.Event.RegisterRenderer(this, EnumRenderStage.Ortho);
            this.capi.Event.MouseMove += OnMouseMove;
            this.capi.Event.MouseDown += OnMouseDown;
        }

        private bool OnHotkeyPressed(KeyCombination comb)
        {
            if (this.menu == null) return false;
            
            if (this.menu.Opened)
            {
                this.menu.Close();
            }
            else
            {
                this.menu.Open();
            }
            return true;
        }

        private void OnMouseMove(MouseEvent e)
        {
            if (this.menu == null || !this.menu.Opened) return;
            this.menu.MouseDeltaMove(e.DeltaX, e.DeltaY);
            e.Handled = true;
        }

        private void OnMouseDown(MouseEvent e)
        {
            if (this.menu == null || !this.menu.Opened) return;
            
            if (e.Button == EnumMouseButton.Left)
            {
                this.menu.Close(true);
            }
            else
            {
                this.menu.Close(false);
            }
            e.Handled = true;
        }

        public void OnRenderFrame(float deltaTime, EnumRenderStage stage)
        {
            if (this.menu == null || !this.menu.Opened) return;
            
            if (this.capi.Render.CurrentActiveShader == null)
            {
                this.capi.Render.GetEngineShader(EnumShaderProgram.Gui).Use();
            }
            this.menu.OnRender(deltaTime);
        }

        protected void LoadTranslations()
        {
            string str = this.capi.Settings.String["language"];
            try
            {
                this.lang = this.capi.Assets.Get<LangConfigFile>(new AssetLocation("emotemenu", "lang/" + str + ".json"));
                this.capi.Logger.Debug("[EmoteMenu] Loaded language file: " + str + ".json");
            }
            catch (Exception)
            {
                this.capi.Logger.Debug("[EmoteMenu] Cannot load language: " + str + ", using default");
                this.lang = new LangConfigFile();
            }
        }

        protected void InitEmoteMenu()
        {
            float scale = this.config.scale;
            this.menu = new RadialMenu(this.capi, (int)(100.0 * scale), (int)(200.0 * scale));
            this.menu.Gape = (int)(5.0 * scale);
            
            if (this.config.show_middle_circle)
            {
                var innerCircle = new DefaulInnerCircleRenderer(this.capi, 6);
                innerCircle.Gape = (int)(8.0 * scale);
                this.menu.InnerRenderer = innerCircle;
                
                this.menu.AddElement(this.BuildElement("wave", () => innerCircle.DisplayedText = this.lang.emote_menu_wave));
                this.menu.AddElement(this.BuildElement("cheer", () => innerCircle.DisplayedText = this.lang.emote_menu_cheer));
                this.menu.AddElement(this.BuildElement("shrug", () => innerCircle.DisplayedText = this.lang.emote_menu_shrug));
                this.menu.AddElement(this.BuildElement("cry", () => innerCircle.DisplayedText = this.lang.emote_menu_cry));
                this.menu.AddElement(this.BuildElement("nod", () => innerCircle.DisplayedText = this.lang.emote_menu_nod));
                this.menu.AddElement(this.BuildElement("facepalm", () => innerCircle.DisplayedText = this.lang.emote_menu_facepalm));
                this.menu.AddElement(this.BuildElement("bow", () => innerCircle.DisplayedText = this.lang.emote_menu_bow));
                this.menu.AddElement(this.BuildElement("laugh", () => innerCircle.DisplayedText = this.lang.emote_menu_laugh));
                this.menu.AddElement(this.BuildElement("rage", () => innerCircle.DisplayedText = this.lang.emote_menu_rage));
            }
            else
            {
                this.menu.AddElement(this.BuildElement("wave", null));
                this.menu.AddElement(this.BuildElement("cheer", null));
                this.menu.AddElement(this.BuildElement("shrug", null));
                this.menu.AddElement(this.BuildElement("cry", null));
                this.menu.AddElement(this.BuildElement("nod", null));
                this.menu.AddElement(this.BuildElement("facepalm", null));
                this.menu.AddElement(this.BuildElement("bow", null));
                this.menu.AddElement(this.BuildElement("laugh", null));
                this.menu.AddElement(this.BuildElement("rage", null));
            }
            this.menu.Rebuild();
            this.capi.Logger.Notification("[EmoteMenu] Menu initialized with " + this.menu.ElementsCount() + " emotes");
        }

        protected void ReloadConfig()
        {
            try
            {
                this.config = this.capi.LoadModConfig<EMConfig>(CONFIG_FILE_NAME);
                if (this.config == null)
                {
                    this.config = new EMConfig();
                    this.capi.StoreModConfig(this.config, CONFIG_FILE_NAME);
                }
            }
            catch (Exception)
            {
                this.capi.Logger.Debug("[EmoteMenu] Cannot load config, using default");
                this.config = new EMConfig();
            }
        }

        private RadialElementPosition BuildElement(string command, Action onHover)
        {
            AssetLocation assetLocation = new AssetLocation("emotemenu", "textures/" + command + ".png");
            LoadedTexture icon = new LoadedTexture(this.capi);
            this.capi.Render.GetOrLoadTexture(assetLocation, ref icon);
            
            RadialElementPosition element = new RadialElementPosition(
                this.capi, 
                icon, 
                () => this.capi.SendChatMessage("/emote " + command)
            );
            
            if (onHover != null)
            {
                element.HoverEvent = (hover) =>
                {
                    if (hover) onHover();
                };
            }
            
            return element;
        }

        public override void Dispose()
        {
            if (this.disposed) return;
            this.disposed = true;
            
            if (this.capi != null)
            {
                this.capi.Event.UnregisterRenderer(this, EnumRenderStage.Ortho);
                this.capi.Event.MouseMove -= OnMouseMove;
                this.capi.Event.MouseDown -= OnMouseDown;
            }
            
            this.menu?.Dispose();
            base.Dispose();
        }
    }
}
