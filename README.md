# JFTOperationPool

```
- (PHImageRequestID)requestImageForAsset:(PHAsset *)asset targetSize:(CGSize)targetSize contentMode:(PHImageContentMode)contentMode options:(nullable PHImageRequestOptions *)options resultHandler:(void (^)(UIImage *_Nullable result, NSDictionary *_Nullable info))resultHandler;
```

实现类似 PHImageManager 的请求 API，根据 cacheKey 缓存 NSOperation，实现任务的复用、根据 requestID 进行任务的 cancel