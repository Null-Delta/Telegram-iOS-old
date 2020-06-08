#import "TGCameraCapturedVideo.h"
#import <AVFoundation/AVFoundation.h>
#import <LegacyComponents/TGMediaAssetImageSignals.h>
#import <LegacyComponents/TGPhotoEditorUtils.h>

#import "LegacyComponentsGlobals.h"
#import "TGStringUtils.h"
#import "TGMediaAsset.h"
#import "TGMediaAsset+TGMediaEditableItem.h"

#import "TGGifConverter.h"

@interface TGCameraCapturedVideo ()
{
    CGSize _cachedSize;
    NSTimeInterval _cachedDuration;
    
    AVURLAsset *_cachedAVAsset;
}
@end

@implementation TGCameraCapturedVideo

+ (NSURL *)videoURLForAsset:(TGMediaAsset *)asset {
    NSURL *convertedGifsUrl = [NSURL fileURLWithPath:[[[LegacyComponentsGlobals provider] dataStoragePath] stringByAppendingPathComponent:@"convertedGifs"]];
    [[NSFileManager defaultManager] createDirectoryAtPath:convertedGifsUrl.path withIntermediateDirectories:true attributes:nil error:nil];
    return [convertedGifsUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", [TGStringUtils md5:asset.identifier]]];
}

- (instancetype)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self != nil)
    {
        _cachedAVAsset = [[AVURLAsset alloc] initWithURL:url options:nil];
        _cachedSize = CGSizeZero;
        _cachedDuration = 0.0;
    }
    return self;
}

- (instancetype)initWithAsset:(TGMediaAsset *)asset
{
    self = [super init];
    if (self != nil)
    {
        _originalAsset = asset;
        
        _cachedSize = CGSizeZero;
        _cachedDuration = 0.0;
    }
    return self;
}

- (void)_cleanUp
{
    if (_originalAsset == nil) {
        [[NSFileManager defaultManager] removeItemAtPath:_cachedAVAsset.URL.path error:nil];
    }
}

- (bool)isVideo
{
    return true;
}

- (bool)isAnimation {
    return _originalAsset != nil;
}

- (SSignal *)avAsset {
    if (_originalAsset != nil) {
        if (_cachedAVAsset != nil) {
             return [SSignal single:_cachedAVAsset];
        } else {
            NSURL *videoUrl = [TGCameraCapturedVideo videoURLForAsset:_originalAsset];
            return [[TGMediaAssetImageSignals imageDataForAsset:_originalAsset allowNetworkAccess:false] mapToSignal:^SSignal *(TGMediaAssetImageData *assetData) {
                NSData *data = assetData.imageData;
                
                const char *gif87Header = "GIF87";
                const char *gif89Header = "GIF89";
                if (data.length >= 5 && (!memcmp(data.bytes, gif87Header, 5) || !memcmp(data.bytes, gif89Header, 5)))
                {
                    return [[TGGifConverter convertGifToMp4:data] map:^id(NSDictionary *result)
                    {
                        NSString *filePath = result[@"path"];
                        [[NSFileManager defaultManager] moveItemAtPath:filePath toPath:videoUrl.path error:nil];
                        
                        return [AVURLAsset assetWithURL:videoUrl];
                    }];
                } else {
                    return [SSignal complete];
                }
            }];
        }
    } else {
        return [SSignal single:_cachedAVAsset];
    }
}

- (NSString *)uniqueIdentifier
{
    if (_originalAsset) {
        return _originalAsset.uniqueIdentifier;
    } else {
        return _cachedAVAsset.URL.absoluteString;
    }
}

- (CGSize)originalSize
{
    if (!CGSizeEqualToSize(_cachedSize, CGSizeZero))
        return _cachedSize;
    
    if (_originalAsset != nil) {
        return [_originalAsset originalSize];
    }
    
    AVAssetTrack *track = _cachedAVAsset.tracks.firstObject;
    _cachedSize = CGRectApplyAffineTransform((CGRect){ CGPointZero, track.naturalSize }, track.preferredTransform).size;
    return _cachedSize;
}

- (NSTimeInterval)videoDuration
{
    return [self originalDuration];
}

- (NSTimeInterval)originalDuration
{
    if (_cachedDuration > DBL_EPSILON)
        return _cachedDuration;
    
    if (_cachedAVAsset != nil) {
        _cachedDuration = CMTimeGetSeconds(_cachedAVAsset.duration);
    }
    return _cachedDuration;
}

- (SSignal *)thumbnailImageSignal
{
    if (_originalAsset != nil) {
        return [_originalAsset thumbnailImageSignal];
    } else {
        CGFloat thumbnailImageSide = TGPhotoEditorScreenImageMaxSize().width;
        CGSize size = TGScaleToSize(self.originalSize, CGSizeMake(thumbnailImageSide, thumbnailImageSide));
    
        return [TGMediaAssetImageSignals videoThumbnailForAVAsset:_cachedAVAsset size:size timestamp:kCMTimeZero];
    }
}

- (SSignal *)screenImageSignal:(NSTimeInterval)position
{
    if (_originalAsset != nil) {
        return [_originalAsset screenImageSignal:position];
    } else {
        CGFloat imageSide = 1280.0f;
        CGSize size = TGScaleToSize(self.originalSize, CGSizeMake(imageSide, imageSide));

        return [TGMediaAssetImageSignals videoThumbnailForAVAsset:_cachedAVAsset size:size timestamp:kCMTimeZero];
    }
}

- (SSignal *)originalImageSignal:(NSTimeInterval)position
{
    return [[self avAsset] mapToSignal:^SSignal *(AVURLAsset *avAsset) {
        return [TGMediaAssetImageSignals videoThumbnailForAVAsset:avAsset size:self.originalSize timestamp:CMTimeMakeWithSeconds(position, NSEC_PER_SEC)];
    }];
}

@end
