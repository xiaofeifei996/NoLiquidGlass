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

static BOOL NLGIsDark(UITraitCollection *trait) {
    return (trait.userInterfaceStyle == UIUserInterfaceStyleDark);
}

static UIBlurEffect *NLGBlurFor(id glassEffect) {
    UITraitCollection *trait = nil;
    @try {
        id v = [glassEffect valueForKey:@"traitCollection"];
        if ([v isKindOfClass:[UITraitCollection class]]) trait = v;
    } @catch (__unused NSException *e) {
    }
    if (!trait) {
        @try {
            trait = [UIScreen mainScreen].traitCollection;
        } @catch (__unused NSException *e) {
        }
    }
    UIBlurEffectStyle style = NLGIsDark(trait)
        ? UIBlurEffectStyleSystemMaterialDark
        : UIBlurEffectStyleSystemMaterialLight;
    return [UIBlurEffect effectWithStyle:style];
}

// 把任意 VisualEffect 归一化成毛玻璃；玻璃就换掉，别的一律原样返回。
static UIVisualEffect *NLGMap(UIVisualEffect *effect) {
    if (!NLGIsGlass(effect)) return effect;
    UIBlurEffect *blur = NLGBlurFor(effect);
    return blur ?: effect;
}

%hook UIVisualEffectView

- (instancetype)initWithEffect:(UIVisualEffect *)effect {
    return %orig(NLGMap(effect));
}

- (void)setEffect:(UIVisualEffect *)effect {
    %orig(NLGMap(effect));
}

%end

%group GlassClassGroup
%hook UIGlassEffect
+ (instancetype)effectWithStyle:(NSInteger)style {
    return (id)[UIBlurEffect effectWithStyle:NLGIsDark([UIScreen mainScreen].traitCollection)
                                             ? UIBlurEffectStyleSystemMaterialDark
                                             : UIBlurEffectStyleSystemMaterialLight];
}
%end
%end

%constructor
static void NLGInit(void) {
    gGlassEffectClass = NSClassFromString(@"UIGlassEffect");
    gGlassContainerClass = NSClassFromString(@"UIGlassContainerEffect");
    // 类可能延迟注册：只在存在时装类方法 hook，避免 hook 失败导致整个 dylib 初始化异常。
    if (gGlassEffectClass &&
        [gGlassEffectClass respondsToSelector:NSSelectorFromString(@"effectWithStyle:")]) {
        %init(GlassClassGroup);
    }
}
