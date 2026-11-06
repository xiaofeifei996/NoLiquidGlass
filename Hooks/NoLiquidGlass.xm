#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// 诊断版：记录玻璃实际经过的对象，用来定位真正的 Hook 点。

static NSString *NLGLogPath(void) {
    return [NSString stringWithFormat:@"/var/mobile/Documents/nlg-%d.log", getpid()];
}

static void NLGLog(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n",
                      [NSDate date], msg];
    FILE *fp = fopen(NLGLogPath().UTF8String, "a");
    if (fp) {
        fputs(line.UTF8String, fp);
        fclose(fp);
    }
}

static void NLGLogOnce(NSString *key, NSString *fmt, ...) {
    static NSMutableSet *seen = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ seen = [NSMutableSet set]; });
    @synchronized (seen) {
        if ([seen containsObject:key]) return;
        [seen addObject:key];
    }
    va_list ap;
    va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NLGLog(@"%@", msg);
}

%group NLGDiag

%hook UIVisualEffectView

- (instancetype)initWithEffect:(UIVisualEffect *)effect {
    if (effect) {
        NLGLogOnce([@"eff:" stringByAppendingString:NSStringFromClass([effect class])],
                   @"UIVisualEffectView effect=%s", object_getClassName(effect));
    }
    return %orig;
}

- (void)setEffect:(UIVisualEffect *)effect {
    if (effect) {
        NLGLogOnce([@"eff:" stringByAppendingString:NSStringFromClass([effect class])],
                   @"setEffect effect=%s", object_getClassName(effect));
    }
    %orig;
}

%end

%end

static void NLGDumpGlassClasses(void) {
    unsigned int total = 0;
    Class *classes = objc_copyClassList(&total);
    NSMutableArray *hits = [NSMutableArray array];
    for (unsigned int i = 0; i < total; i++) {
        const char *n = class_getName(classes[i]);
        if (!n) continue;
        NSString *s = @(n);
        if ([s containsString:@"Glass"] || [s containsString:@"Solarium"] ||
            [s containsString:@"CoreMaterial"] || [s containsString:@"Backdrop"]) {
            [hits addObject:s];
        }
    }
    free(classes);
    NLGLog(@"matched classes (%lu): %@", (unsigned long)hits.count,
           [[hits sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@", "]);
}

%ctor {
    NLGLog(@"=== NoLiquidGlass diag pid=%d ===", getpid());
    NLGLog(@"UIGlassEffect=%@ UIGlassContainerEffect=%@",
           NSStringFromClass(NSClassFromString(@"UIGlassEffect")) ?: @"nil",
           NSStringFromClass(NSClassFromString(@"UIGlassContainerEffect")) ?: @"nil");
    NLGLog(@"CABackdropLayer=%@",
           NSStringFromClass(NSClassFromString(@"CABackdropLayer")) ?: @"nil");
    NLGDumpGlassClasses();
    %init(NLGDiag);
    NLGLog(@"hooks installed");
}
