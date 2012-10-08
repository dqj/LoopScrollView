//
//  ZBScrollView.h
//  YouHui
//
//  Created by dqj on 12-8-24.
//  Copyright (c) 2012年 netease. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ZBScrollView;

@protocol ZBScrollViewDelegate <UIScrollViewDelegate>
@optional
//
// Called when the page will be unloaded -
// we used to call "viewDidUnload" - but this method will be deprecated in iOS 6
// Please destroy all your views in that delegate call
// otherwise your app will leak!!
- (void)zbScrollView:(ZBScrollView*)scrollView
             unloadPage:(UIView*)view
          forController:(UIViewController*)controller;
//
// Called when page has changed
//
- (void)zbScrollView:(ZBScrollView*)scrollView pageChanged:(NSIndexPath*)indexPath;

//
// The standard UIScrollView Delegates
//
- (void)scrollViewDidScroll:(ZBScrollView *)scrollView;

- (void)scrollViewWillBeginDragging:(ZBScrollView *)scrollView;
- (void)scrollViewDidEndDragging:(ZBScrollView *)scrollView willDecelerate:(BOOL)decelerate;

- (void)scrollViewDidEndDecelerating:(ZBScrollView *)scrollView;
- (void)scrollViewWillBeginDecelerating:(ZBScrollView *)scrollView;

- (void)scrollViewDidScrollToTop:(ZBScrollView *)scrollView;
- (void)scrollViewDidEndScrollingAnimation:(ZBScrollView *)scrollView;

@end


/*
 * ZBScrollView DataSource Methods
 *
 */
@protocol ZBScrollViewDataSource <UIScrollViewDelegate>

@required
- (NSInteger)GetNumberOfPagesFromZBScrollView:(ZBScrollView *)scrollView;
@optional

- (NSInteger)numberOfSectionsInZBScrollView:(ZBScrollView *)scrollView;        // Default is 1 if not implemented

- (UIView*)zbScrollView:(ZBScrollView*)scrollView viewForPageAtIndexPath:(NSIndexPath *)indexPath;

- (UIViewController*)zbScrollView:(ZBScrollView*)scrollView controllerForPageAtIndexPath:(NSIndexPath *)indexPath;

- (NSInteger)numberOfLazyLoadingPages;

@end



typedef enum {
    ZBScrollViewDirectionHorizontal = 0,
    ZBScrollViewDirectionVertical = 1,
} ZBScrollViewDirection;



@interface ZBScrollView : UIScrollView <UIScrollViewDelegate> {
	
	id <ZBScrollViewDataSource> __unsafe_unretained _dataSource;
	id <ZBScrollViewDelegate>  __unsafe_unretained  delegate_;
    
	NSMutableSet                    *_recycledPages;
    NSMutableSet                    *_visiblePages;
    NSMutableArray                  *_pageController;
    
	NSInteger                       _currentPageIndex;
    
    NSMutableArray                  *_indexPages;
    
	CGFloat                         _currentWidth;
    CGFloat                         _pagePadding;
    CGSize                          _pageSizeWithPadding;
    ZBScrollViewDirection        _direction;
}


// Set the DataSource for the Scroll Suite
@property (nonatomic, assign, unsafe_unretained) id <ZBScrollViewDataSource> dataSource;

// set the Delegate for the Scroll Suite
@property (nonatomic, assign, unsafe_unretained) id <ZBScrollViewDelegate> delegate;

// Set the padding between pages. Default is 10pt
@property (nonatomic, assign) CGFloat             pagePadding;

// Set a Vertical or Horizontal Direction of the scrolling
@property (nonatomic, assign) ZBScrollViewDirection direction;

//  Get the current visible Page
@property (nonatomic, readonly) UIView *currentPage;

//  Get the first Page
@property (nonatomic, readonly) UIView *firstPage;

//  Get the last Page
@property (nonatomic, readonly) UIView *lastPage;

//  Get the current visible indexPath
@property (nonatomic, readonly) NSInteger *currentIndexPath;

//  Get the last indexPath of the Scroll Suite
@property (nonatomic, readonly) NSInteger *lastIndexPath;

//  Get all Page Controller if given
@property (nonatomic, readonly) NSArray *pageController;

/*
 * Init Method for PunchScrollView
 *
 */
- (id)init;
- (id)initWithFrame:(CGRect)aFrame;

/*
 * This Method returns a UIView which is in the Queue
 */
- (UIView *)dequeueRecycledPage;

/*
 * This Method reloads the data in the scrollView
 */
- (void)reloadData;


/*
 * This Method returns an UIView for a given indexPath
 *
 */
- (UIView*)pageForIndexPath:(NSIndexPath*)indexPath;

/*
 * Some Scrolling to page methods
 *
 */
- (void)scrollToIndexPath:(NSIndexPath*)indexPath animated:(BOOL)animated;
- (void)scrollToNextPage:(BOOL)animated;
- (void)scrollToPreviousPage:(BOOL)animated;

@end
