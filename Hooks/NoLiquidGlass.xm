#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// iOS 26 的液态玻璃（Solarium）通过 UIGlassEffect / UIGlassContainerEffect 施加到
// UIVisualEffectView 上。系统的「关闭玻璃」偏好开关走的是另一条回退渲染路径，
// 它会把材质层整个丢掉、露出不透明白底 —— 控制中心、文件夹、搜索框于是变成白块。
//
// 这里换思路：系统仍认为玻璃是开着的（不会掉进白色回退路径），
// 只在运行时把玻璃效果替换成普通 UIBlurEffect，得到 iOS 16 那种毛玻璃观感。

static Class gGlassEffectClass = Nil;
static Class gGlassContainerClass = Nil;

static BOOL NLGIsGlass(id effect) {
    if (!effect) return NO;
    if (gGlassEffectClass && [effect isKindOfClass:gGlassEffectClass]) return YES;
    if (gGlassContainerClass && [effect isKindOfClass:gGlassContainerClass]) return YES;
    NSString *name = NSStringFromClass([effect class]);
    return [name containsString:@"GlassEffect"] || [name containsString:@"GlassContainer"];
}

static BOOL NLGDark(void) {
    return ([UIScreen mainScreen].traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
}

static UIBlurEffect *NLGBlur(void) {
    UIBlurEffectStyle style = NLGDark() ? UIBlurEffectStyleSystemMaterialDark
                                        : UIBlurEffectStyleSystemMaterialLight;
    return [UIBlurEffect effectWithStyle:style];
}

static UIVisualEffect *NLGMap(UIVisualEffect *effect) {
    if (!NLGIsGlass(effect)) return effect;
    UIBlurEffect *blur = NLGBlur();
    return blur ?: effect;
}

%group NLGCore

%hook UIVisualEffectView

- (instancetype)initWithEffect:(UIVisualEffect *)effect {
    return %orig(NLGMap(effect));
}

- (void)setEffect:(UIVisualEffect *)effect {
    %orig(NLGMap(effect));
}

%end

// 部分代码路径直接用类方法造玻璃，兜一层。
%hook UIGlassEffect

+ (instancetype)effectWithStyle:(NSInteger)style {
    return (id)NLGBlur();
}

%end

%end  // NLGCore

%constructor
static void NLGInit(void) {
    gGlassEffectClass = NSClassFromString(@"UIGlassEffect");
    gGlassContainerClass = NSClassFromString(@"UIGlassContainerEffect");
    %init(NLGCore);
}
