/*
 Copyright 2016-present the Material Components for iOS authors. All Rights Reserved.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "MDCProgressView.h"

#include <tgmath.h>

#import "MDFInternationalization.h"
#import "MaterialMath.h"
#import "MaterialPalettes.h"
#import <MotionAnimator/MotionAnimator.h>
#import "private/MDCProgressView+MotionSpec.h"

static inline UIColor *MDCProgressViewDefaultTintColor(void) {
  return MDCPalette.bluePalette.tint500;
}

// The ratio by which to desaturate the progress tint color to obtain the default track tint color.
static const CGFloat MDCProgressViewTrackColorDesaturation = 0.3f;

@interface MDCProgressView ()
@property(nonatomic, strong) UIView *progressView;
@property(nonatomic, strong) UIView *trackView;
@property(nonatomic) BOOL animatingHide;
// A UIProgressView to return the same format for the accessibility value. For example, when
// progress is 0.497, it reports "fifty per cent".
@property(nonatomic, readonly) UIProgressView *accessibilityProgressView;
@property(nonatomic, strong) MDMMotionAnimator *animator;
@end

@implementation MDCProgressView

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self commonMDCProgressViewInit];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    [self commonMDCProgressViewInit];
  }
  return self;
}

- (void)commonMDCProgressViewInit {
  _animator = [[MDMMotionAnimator alloc] init];

  self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
  self.backgroundColor = [UIColor clearColor];
  self.clipsToBounds = YES;
  self.isAccessibilityElement = YES;

  _backwardProgressAnimationMode = MDCProgressViewBackwardAnimationModeReset;

  _trackView = [[UIView alloc] initWithFrame:self.frame];
  _trackView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  [self addSubview:_trackView];

  _progressView = [[UIView alloc] initWithFrame:CGRectZero];
  [self addSubview:_progressView];

  _progressView.backgroundColor = MDCProgressViewDefaultTintColor();
  _trackView.backgroundColor =
      [[self class] defaultTrackTintColorForProgressTintColor:_progressView.backgroundColor];
}

- (void)willMoveToSuperview:(UIView *)superview {
  [super willMoveToSuperview:superview];
  [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)layoutSubviews {
  [super layoutSubviews];

  // Don't update the views when the hide animation is in progress.
  if (!self.animatingHide) {
    [self updateProgressView];
    [self updateTrackView];
  }
}

- (UIColor *)progressTintColor {
  return self.progressView.backgroundColor;
}

- (void)setProgressTintColor:(UIColor *)progressTintColor {
  if (progressTintColor == nil) {
    progressTintColor = MDCProgressViewDefaultTintColor();
  }
  self.progressView.backgroundColor = progressTintColor;
}

- (UIColor *)trackTintColor {
  return self.trackView.backgroundColor;
}

- (void)setTrackTintColor:(UIColor *)trackTintColor {
  if (trackTintColor == nil) {
    trackTintColor =
        [[self class] defaultTrackTintColorForProgressTintColor:self.progressTintColor];
  }
  self.trackView.backgroundColor = trackTintColor;
}

- (void)setProgress:(float)progress {
  if (progress > 1)
    progress = 1;
  if (progress < 0)
    progress = 0;
  _progress = progress;
  [self accessibilityValueDidChange];
  [self setNeedsLayout];
}

- (void)setProgress:(float)progress
           animated:(BOOL)animated
         completion:(void (^__nullable)(BOOL finished))completion {
  if (progress < self.progress &&
      self.backwardProgressAnimationMode == MDCProgressViewBackwardAnimationModeReset) {
    self.progress = 0;
    [self updateProgressView];
  }

  self.progress = progress;

  if (!animated) {
    [self updateProgressView];

  } else {
    MDMMotionTiming timing = kMDCProgressViewMotionSpec.setProgress;
    [_animator animateWithTiming:timing animations:^{
      [self updateProgressView];
    } completion:^{
      if (completion) {
        completion(YES);
      }
    }];
  }
}

- (void)setHidden:(BOOL)hidden {
  [super setHidden:hidden];
  UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, hidden ? nil : self);
}

- (void)setHidden:(BOOL)hidden
         animated:(BOOL)animated
       completion:(void (^__nullable)(BOOL finished))completion {
  if (hidden == self.hidden) {
    if (completion) {
      completion(YES);
    }
    return;
  }

  void (^animations)(void);

  if (hidden) {
    self.animatingHide = YES;
    animations = ^{
      CGFloat y = CGRectGetHeight(self.bounds);

      CGRect trackViewFrame = self.trackView.frame;
      trackViewFrame.origin.y = y;
      trackViewFrame.size.height = 0;
      self.trackView.frame = trackViewFrame;

      CGRect progressViewFrame = self.progressView.frame;
      progressViewFrame.origin.y = y;
      progressViewFrame.size.height = 0;
      self.progressView.frame = progressViewFrame;
    };
  } else {
    self.hidden = NO;
    animations = ^{
      self.trackView.frame = self.bounds;

      CGRect progressViewFrame = self.progressView.frame;
      progressViewFrame.origin.y = 0;
      progressViewFrame.size.height = CGRectGetHeight(self.bounds);
      self.progressView.frame = progressViewFrame;
    };
  }

  if (animated) {
    MDMMotionTiming timing = kMDCProgressViewMotionSpec.setHidden;
    [_animator animateWithTiming:timing animations:animations completion:^{
      if (hidden) {
        self.animatingHide = NO;
        self.hidden = YES;
      }
      if (completion) {
        completion(YES);
      }
    }];

  } else {
    animations();
    if (completion) {
      completion(YES);
    }
  }
}

#pragma mark Accessibility

- (UIProgressView *)accessibilityProgressView {
  // Accessibility values are determined by querying a UIProgressView set to the same value as our
  // MDCProgressView.
  static UIProgressView *accessibilityProgressView;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    accessibilityProgressView = [[UIProgressView alloc] init];
  });

  return accessibilityProgressView;
}

- (NSString *)accessibilityValue {
  self.accessibilityProgressView.progress = self.progress;
  return self.accessibilityProgressView.accessibilityValue;
}

- (void)accessibilityValueDidChange {
  // Store a strong reference to self until the end of the method. Indeed,
  // a previous -performSelector:withObject:afterDelay: might be the last thing
  // to retain self, so calling +cancelPreviousPerformRequestsWithTarget: might
  // deallocate self.
  MDCProgressView *strongSelf = self;
  // Cancel unprocessed announcements and replace them with the most up-to-date
  // value. That way, they don't overlap and don't spam the user.
  [NSObject cancelPreviousPerformRequestsWithTarget:strongSelf
                                           selector:@selector(announceAccessibilityValueChange)
                                             object:nil];
  // Schedule a new announcement.
  [strongSelf performSelector:@selector(announceAccessibilityValueChange)
                   withObject:nil
                   afterDelay:1];
}

- (void)announceAccessibilityValueChange {
  if ([self accessibilityElementIsFocused]) {
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,
                                    [self accessibilityValue]);
  }
}

#pragma mark Private

+ (UIColor *)defaultTrackTintColorForProgressTintColor:(UIColor *)progressTintColor {
  CGFloat hue, saturation, brightness, alpha;
  if ([progressTintColor getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha]) {
    CGFloat newSaturation = MIN(saturation * MDCProgressViewTrackColorDesaturation, 1.0f);
    return [UIColor colorWithHue:hue saturation:newSaturation brightness:brightness alpha:alpha];
  }
  return [UIColor clearColor];
}

- (void)updateProgressView {
  // Update progressView with the current progress value.
  CGFloat progressWidth = MDCCeil(self.progress * CGRectGetWidth(self.bounds));
  CGRect progressFrame = CGRectMake(0, 0, progressWidth, CGRectGetHeight(self.bounds));
  if (self.mdf_effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft) {
    progressFrame = MDFRectFlippedHorizontally(progressFrame, CGRectGetWidth(self.bounds));
  }
  self.progressView.frame = progressFrame;
}

- (void)updateTrackView {
  const CGSize size = self.bounds.size;
  self.trackView.frame = self.hidden ? CGRectMake(0.0, size.height, size.width, 0.0) : self.bounds;
}

@end
