#import "HiraganyGlobal.h"
#import "ConversionEngine.h"

#define kMaxParticleLength 2

@interface ConversionEngine(Private)
-(id)loadPlist:(NSString*)name;
-(void)testForDebug;
@end

@implementation ConversionEngine

@synthesize katakana = katakana_;

-(void)awakeFromNib {
    katakana_ = NO;
    romakanaDic_ = [self loadPlist:@"RomaKana"];
    kanakanjiDic_ = [self loadPlist:@"KanaKanji"];
    symbolDic_ = [self loadPlist:@"Symbol"];
    particleDic_ = [self loadPlist:@"Particle"];

#ifdef DEBUG
    [self testForDebug];
#endif
}

-(void)dealloc {
    [romakanaDic_ release];
    [kanakanjiDic_ release];
    [symbolDic_ release];
    [particleDic_ release];
    [super dealloc];
}

-(NSArray*)convertRomanToKana:(NSString*)string {
    if (!romakanaDic_) return [NSArray arrayWithObjects:@"", string, nil];
    
    NSMutableString* buf = [[NSMutableString new] autorelease];
    NSRange range;
    range.location = 0;
    range.length = 0;
    
    NSString* key = katakana_ ? [string uppercaseString] : [string lowercaseString];
    for (int i = 0; i < [key length]; i++) {
        range.length += 1;
        NSString* k = [key substringWithRange: range];
        NSString* converted = [romakanaDic_ objectForKey:k];
        if (converted) {
            DebugLog(@"conversion: %@", converted);
            if ([self isSymbol:k]) {
                return [NSArray arrayWithObjects:buf, converted, nil];
            }                
            range.location += range.length;
            range.length = 0;
            [buf appendString:converted];
        } else if ([k length] > 1) {
            unichar firstChar = [k characterAtIndex:0];
            unichar secondChar = [k characterAtIndex:1];
            if (firstChar == secondChar) {
                [buf appendString:(katakana_ ? @"ッ" : @"っ")];
                range.location++;
                range.length--;
                continue;
            }
            if (firstChar == 'n') {  // n is special
                NSString* n = [romakanaDic_ objectForKey:[NSString stringWithFormat:@"%@a", k]];
                if (!n) {
                    [buf appendString:@"ん"];
                    range.location++;
                    range.length--;
                }
            } else if (firstChar == 'N') {  // N is awesome
                NSString* n = [romakanaDic_ objectForKey:[NSString stringWithFormat:@"%@A", k]];
                if (!n) {
                    [buf appendString:@"ン"];
                    range.location++;
                    range.length--;
                }
            }
            NSString* symbol = [NSString stringWithCharacters:&secondChar length:1];
            if ([self isSymbol:symbol]) {
                if (firstChar != 'n' && firstChar != 'N') {
                    [buf appendString:[NSString stringWithCharacters:&firstChar length:1]];
                    range.location++;
                }
                NSString* converted = [romakanaDic_ objectForKey:symbol];
                return [NSArray arrayWithObjects:buf, converted, nil];
            }
        }
    }
    
    if (range.length) {
        return [NSArray arrayWithObjects:buf, [key substringWithRange:range], nil];
    }
    return [NSArray arrayWithObjects:buf, nil];
}

-(NSArray*)convertKanaToKanji:(NSString*)string {
    if (!kanakanjiDic_) return [NSArray arrayWithObjects:@"", string, nil];
    
    NSString* converted = [kanakanjiDic_ objectForKey:string];
    if (converted) {
        return [NSArray arrayWithObject:converted];
    }
    for (int i = 1; i <= kMaxParticleLength; i++) {
        NSInteger len = [string length] - i;
        if (len <= 0) break;
        NSString* particle = [string substringFromIndex:len];
        if ([particleDic_ objectForKey:particle]) {
            converted = [kanakanjiDic_ objectForKey:[string substringToIndex:len]];
            if (converted) {
                return [NSArray arrayWithObjects:converted, particle, nil];
            }
        }
    }
    return [NSArray arrayWithObjects:@"", string, nil];
}

-(NSString*)convertHiraToKata:(NSString*)string {
    CFMutableStringRef buf = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, (CFStringRef)string);
    CFRange range = CFRangeMake(0, [string length]);
    CFStringTransform(buf, &range, kCFStringTransformHiraganaKatakana, NO);
    return (NSString*)buf;
}

-(NSArray*)convert:(NSString*)string {
    NSArray* results;
    NSArray* kana = [self convertRomanToKana:string];
    NSArray* converted = [self convertKanaToKanji:[kana objectAtIndex:0]];
    if ([kana count] == 1) {
        results = converted;
    } else {
        if ([converted count] == 1) {
            results = [NSArray arrayWithObjects:[converted objectAtIndex:0], [kana objectAtIndex:1], nil];
        } else {
            results = [NSArray arrayWithObjects:[converted objectAtIndex:0],
                       [NSString stringWithFormat:@"%@%@", [converted objectAtIndex:1], [kana objectAtIndex:1]], nil];
        }
    }
    if (verbosity_) {
        if ([kana count] == 1) {
            if ([results count] == 1)
                NSLog(@"convert: %@ -> %@ -> %@", string,
                      [kana objectAtIndex:0], [results objectAtIndex:0]);
            else
                NSLog(@"convert: %@ -> %@ -> %@/%@",
                      string, [kana objectAtIndex:0], [results objectAtIndex:0], [results objectAtIndex:1]);
        } else {
            if ([results count] == 1)
                NSLog(@"convert: %@ -> %@/%@ -> %@", string,
                      [kana objectAtIndex:0], [kana objectAtIndex:1], [results objectAtIndex:0]);
            else
                NSLog(@"convert: %@ -> %@/%@ -> %@/%@",
                      string, [kana objectAtIndex:0], [kana objectAtIndex:1], [results objectAtIndex:0], [results objectAtIndex:1]);
        }
    }
    return results;
}

-(BOOL)isSymbol:(NSString*)string {
    return [symbolDic_ objectForKey:string] ? YES : NO;
}

# pragma mark -

-(id)loadPlist:(NSString*)name {
    NSString* errorDesc = nil;
    NSPropertyListFormat format;
    NSString* plistPath = [[NSBundle mainBundle] pathForResource:name ofType:@"plist"];
    NSData* plistXML = [[NSFileManager defaultManager] contentsAtPath:plistPath];
    id plist = [NSPropertyListSerialization propertyListFromData:plistXML
                                                mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                                          format:&format
                                                errorDescription:&errorDesc];    
    if (plist) {
        NSLog(@"Plist has been loaded: %@", name);
        [plist retain];
    } else {
        NSLog(errorDesc);
        [errorDesc release];
    }
    return plist;
}

-(void)testForDebug {
    verbosity_ = 9;
    [self convert:@"d"];
    [self convert:@"do"];
    [self convert:@"dok"];
    [self convert:@"dokk"];
    [self convert:@"dokkin"];
    [self convert:@"dokkinho"];
    [self convert:@"dokkinhou"];
    [self convert:@"gassyuku"];
    [self convert:@"keppaku"];
    [self convert:@"misshi"];
    [self convert:@"misshiha"];
    [self convert:@"misshitoha"];
    [self convert:@"misshitohana"];
    [self convert:@"misshitsu"];
    [self convert:@"misshitsudemo"];
    [self convert:@"runrun"];
    [self convert:@"runrun "];
    [self convert:@"runnrun"];
    [self convert:@"ronten"];
    [self convert:@"ronten."];
    [self convert:@"rontenn"];
    [self convert:@"rontenn."];
    [self convert:@"w."];
    [self convert:@"ww."];
    [self convert:@"www."];
    verbosity_ = 0;
}

@end
