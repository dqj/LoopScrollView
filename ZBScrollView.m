//
//  ZBScrollView.m
//  YouHui
//
//  Created by dqj on 12-8-24.
//  Copyright (c) 2012年 netease. All rights reserved.
//

#import "ZBScrollView.h"

@interface ZBScrollView ()
{
    BOOL _orientationChangeInProcess;
}

@property (nonatomic, readonly) CGSize pageSizeWithPadding;
@property (nonatomic, readonly) NSArray *storedPages;

- (UIView*)askDataSourceForPageAtIndex:(NSInteger)index;
- (BOOL)isDisplayingPageForIndex:(NSUInteger)index;
- (CGRect)frameForPageAtIndex:(NSUInteger)index withSize:(CGSize)size;
- (void)updateFrameForAvailablePages;
- (void)updateContentSize;
- (void)loadPages;
- (void)pageIndexChanged;
- (void)setIndexPaths;
- (NSUInteger)sectionCount;
- (NSUInteger)pagesCount;
- (NSIndexPath*)indexPathForIndex:(NSInteger)index;

@end

@implementation ZBScrollView
@synthesize dataSource = _dataSource;
@synthesize delegate = delegate_;

@synthesize pagePadding = _pagePadding;
@synthesize direction = _direction;

@dynamic currentIndexPath;
@dynamic lastIndexPath;
@dynamic currentPage;
@dynamic firstPage;
@dynamic lastPage;
@dynamic pageController;

- (id)init
{
    return [self initWithFrame:[[UIScreen mainScreen] bounds]];
}

- (id)initWithFrame:(CGRect)aFrame
{
    if ((self = [super initWithFrame:aFrame]))
	{
        _pageSizeWithPadding = CGSizeZero;
        
        self.pagePadding = 0;
        
        self.bouncesZoom = YES;
        self.decelerationRate = UIScrollViewDecelerationRateFast;
        [super setDelegate:self];
 		//self.pagingEnabled = YES;
		self.showsVerticalScrollIndicator = NO;
		self.showsHorizontalScrollIndicator = NO;
		self.directionalLockEnabled = YES;
		
        _indexPages = [[NSMutableArray alloc] init];
        
		_recycledPages  = [[NSMutableSet alloc] init];
		_visiblePages   = [[NSMutableSet alloc] init];
		
    }
    return self;
}



- (void)dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
    self.dataSource = nil;
	self.delegate = nil;
	
	_indexPages = nil;
	_recycledPages = nil;
	_visiblePages = nil;
    _pageController = nil;
    
    [super dealloc];
}

#pragma mark -
#pragma mark ZBScrollView Public Methods

- (UIView *)dequeueRecycledPage
{
    UIView *page = [_recycledPages anyObject];
    if (page)
    {
        [[page retain] autorelease];
        [_recycledPages removeObject:page];
        [page removeFromSuperview];
    }
    return page;
}

- (NSArray*)storedPages
{
    NSArray *storedPages = [NSArray arrayWithArray:[_recycledPages allObjects]];
    
    return [storedPages arrayByAddingObjectsFromArray:[_visiblePages allObjects]];
}
//important
- (UIView*)pageForIndex:(NSInteger*)index
{
    
    for (UIView *thePage in self.storedPages)
	{
		if ((NSNull*)thePage == [NSNull null]) break;
		NSInteger *storedIndex = [self indexPathForIndex:thePage.tag];
		
        if (storedIndex==index)
		{
            return thePage;
        }
    }
	
    return nil;
}

- (void)scrollToIndex:(NSInteger*)index animated:(BOOL)animated
{
	NSInteger pageNum = 0;
    BOOL indexPathFound = NO;
    
	for (NSInteger *storedPath in _indexs)
	{
		if (storedPath==index)
		{
			indexPathFound = YES;
            break;
		}
        
		pageNum++;
	}
	
    if (indexPathFound == NO)
    {
        // The indexPath is not avaiable. go out, but do not crash and burn
        return;
    }
    
    
    if (_direction == ZBScrollViewDirectionHorizontal)
    {
        
        [self setContentOffset:CGPointMake(self.pageSizeWithPadding.width*pageNum,
                                           0)
                      animated:animated];
	}
    else if (_direction == ZBScrollViewDirectionVertical)
    {
        [self setContentOffset:CGPointMake(0,
                                           self.pageSizeWithPadding.height*pageNum)
                      animated:animated];
    }
	if (animated == NO)
	{
		[self pageIndexChanged];
	}
}


- (void)scrollToNextPage:(BOOL)animated
{
	NSIndexPath *indexPath = [self indexPathForIndex:_currentPageIndex+1];
    
    if (indexPath != nil)
    {
        [self scrollToIndexPath:indexPath animated:animated];
        if (animated == NO)
        {
            [self pageIndexChanged];
        }
    }
}

- (void)scrollToPreviousPage:(BOOL)animated
{
	NSIndexPath *indexPath = [self indexPathForIndex:_currentPageIndex-1];
    
    if (indexPath != nil)
    {
        [self scrollToIndexPath:indexPath animated:animated];
        if (animated == NO)
        {
            [self pageIndexChanged];
        }
    }
}


- (NSInteger*)currentIndexPath
{
	if (_currentPageIndex >= [_indexPages count])
    {
        return nil;
    }
    return [self indexPathForIndex:_currentPageIndex];
}

- (NSIndexPath*)lastIndexPath
{
	return [_indexPages lastObject];
}

- (UIView*)currentPage
{
    return [self pageForIndexPath:self.currentIndexPath];
}

- (UIView*)firstPage
{
    return [self pageForIndexPath:0];
}

- (UIView*)lastPage
{
    return [self pageForIndexPath:self.lastIndexPath];
}

- (NSArray*)pageController
{
    return _pageController;
}

- (void)reloadData
{
    [self setIndexPaths];
    
    _pageSizeWithPadding = CGSizeZero;
    
    for (UIView *view in self.storedPages)
    {
        [view removeFromSuperview];
        view = nil;
    }
    
    [_visiblePages removeAllObjects];
    [_recycledPages removeAllObjects];
    
    [self updateContentSize];
    
    if (_direction == ZBScrollViewDirectionHorizontal)
    {
        [self setContentOffset:CGPointMake(self.pageSizeWithPadding.width*_currentPageIndex, 0)
                      animated:NO];
    }
    else if (_direction == ZBScrollViewDirectionVertical)
    {
        [self setContentOffset:CGPointMake(0, self.pageSizeWithPadding.height*_currentPageIndex)
                      animated:NO];
    }
    [self loadPages];
}



#pragma mark -
#pragma mark -
#pragma mark Tiling and page configuration
- (void)layoutSubviews
{
	[super layoutSubviews];
    
    _orientationChangeInProcess = NO;
	if (_currentWidth != self.frame.size.width)
	{
        _pageSizeWithPadding = CGSizeZero;
		_orientationChangeInProcess = YES;
	}
	
	_currentWidth = self.frame.size.width;
	
    [self updateContentSize];
    
	if (_orientationChangeInProcess == YES)
	{
		if (_direction == ZBScrollViewDirectionHorizontal)
        {
            [self setContentOffset:CGPointMake(self.pageSizeWithPadding.width*_currentPageIndex, 0)
                          animated:NO];
        }
        else if (_direction == ZBScrollViewDirectionVertical)
        {
            [self setContentOffset:CGPointMake(0, self.pageSizeWithPadding.height*_currentPageIndex)
                          animated:NO];
        }
        
        [self updateFrameForAvailablePages];
    }
    
    _orientationChangeInProcess = NO;
}

- (void)loadPages
{
    if ([self pagesCount]  == 0 ||
        (self.dataSource == nil))
    {
        
        // do not render the pages if there is not at least one page
        
        return;
    }
    
    int lazyOfLoadingPages = 0;
    NSMutableArray *controllerViewsToDelete = [[NSMutableArray alloc] init];
    
    if ([self.dataSource respondsToSelector:@selector(numberOfLazyLoadingPages)])
    {
        lazyOfLoadingPages = [self.dataSource numberOfLazyLoadingPages]-1;
    }
    
    // Calculate which pages are visible
    CGRect visibleBounds = self.bounds;
    int firstNeededPageIndex = floorf(CGRectGetMinX(visibleBounds) / CGRectGetWidth(visibleBounds));
    int lastNeededPageIndex  = ceil(CGRectGetMaxX(visibleBounds) / self.pageSizeWithPadding.width);
    
    if (_direction == ZBScrollViewDirectionVertical)
    {
        firstNeededPageIndex = floorf(CGRectGetMinY(visibleBounds) / CGRectGetHeight(visibleBounds));
        lastNeededPageIndex  = ceil(CGRectGetMaxY(visibleBounds) / self.pageSizeWithPadding.height);
    }
    
    firstNeededPageIndex = MAX(firstNeededPageIndex-lazyOfLoadingPages-1, 0);
    lastNeededPageIndex  = MIN(lastNeededPageIndex+lazyOfLoadingPages, [self pagesCount] - 1);
    
    // Recycle no-longer-visible pages
    for (UIView *page in _visiblePages)
    {
        int indexToDelete = page.tag;
        if (indexToDelete < firstNeededPageIndex ||
            indexToDelete > lastNeededPageIndex)
        {
            //
            // If we work in controller mode
            if (_pageController != nil &&
                indexToDelete >= 0 &&
                indexToDelete < [_pageController count])
            {
                UIViewController *vc = [_pageController objectAtIndex:indexToDelete];
                [controllerViewsToDelete addObject:vc];
            }
            //
            // if we work in view mode
            else if (_pageController == nil)
            {
                [_recycledPages addObject:page];
            }
            
        }
    }
    
    [_visiblePages minusSet:_recycledPages];
    
    //
    // Force Deletion
    for (UIViewController *vc in controllerViewsToDelete)
    {
        [_visiblePages removeObject:vc.view];
        if ([self.delegate respondsToSelector:@selector(zbScrollView:unloadPage:forController:)])
        {
            [self.delegate zbScrollView:self unloadPage:vc.view forController:vc];
        }
        
        //[vc viewDidUnload];  // deprecated in iOS 6
        vc.view = nil;
    }
    [controllerViewsToDelete release];
    
    
    //
    // add missing pages
    for (int index = firstNeededPageIndex; index <= lastNeededPageIndex; index++)
    {
        if (![self isDisplayingPageForIndex:index])
		{
			
			UIView *page = [self askDataSourceForPageAtIndex:index];
            
			if (nil != page)
			{
				page.tag = index;
				[page layoutIfNeeded];
                page.frame = [self frameForPageAtIndex:index withSize:page.frame.size];
				[self addSubview:page];
				[_visiblePages addObject:page];
				
			}
			else
			{
				[_visiblePages addObject:[NSNull null]];
			}
			
        }
    }
}

- (UIView*)askDataSourceForPageAtIndex:(NSInteger)index
{
    UIView *page = nil;
    
    if ([self.dataSource respondsToSelector:@selector(zbScrollView:controllerForPageAtIndexPath:)])
    {
        if (_pageController == nil)
        {
            _pageController = [[NSMutableArray alloc] init];
        }
        
        UIViewController *controller = [self.dataSource
                                        zbScrollView:self
                                        controllerForPageAtIndexPath:[self indexPathForIndex:index]];
        if (![_pageController containsObject:controller] &&
            controller != nil)
        {
            [_pageController addObject:controller];
        }
        
        page = controller.view;
        
    }
    else if ([self.dataSource respondsToSelector:@selector(zbScrollView:viewForPageAtIndexPath:)])
    {
        page = [self.dataSource zbScrollView:self viewForPageAtIndexPath:[self indexPathForIndex:index]];
    }
    
    
    return page;
}


- (BOOL)isDisplayingPageForIndex:(NSUInteger)index
{
    BOOL foundPage = NO;
    for (UIView *page in _visiblePages)
    {
        if (page.tag == index)
        {
            return YES;
        }
    }
    return foundPage;
}

- (void)setDataSource:(id <ZBScrollViewDataSource>)thedataSource
{
	if (_dataSource != thedataSource)
    {
        _dataSource = thedataSource;
        if (_dataSource != nil)
        {
            [self performSelector:@selector(reloadData)
                       withObject:nil
                       afterDelay:0.0];
        }
    }
}

- (void)setDelegate:(id<ZBScrollViewDelegate>)aDelegate
{
    [super setDelegate:self];
    
    if (aDelegate != self->delegate_)
    {
        self->delegate_ = aDelegate;
        if (aDelegate != nil)
        {
            [self performSelector:@selector(reloadData)
                       withObject:nil
                       afterDelay:0.0];
        }
    }
}


#pragma mark -
#pragma mark ScrollView delegate methods


- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    
    //
    // Check if the page really has changed
    //
    BOOL pageChanged = NO;
    if (_direction == ZBScrollViewDirectionHorizontal)
    {
        if ( (int)(self.contentOffset.x) % MAX((int)(self.pageSizeWithPadding.width),1) == 0)
        {
            pageChanged = YES;
        }
	}
    else if (_direction == ZBScrollViewDirectionVertical)
    {
        if ( (int)(self.contentOffset.y) % MAX((int)(self.pageSizeWithPadding.height),1) == 0)
        {
            pageChanged = YES;
        }
    }
    
    
    if (pageChanged == YES &&
        _orientationChangeInProcess == NO)
    {
        [self pageIndexChanged];
    }
    
    if ([self.delegate respondsToSelector:@selector(scrollViewDidScroll:)])
    {
        [self.delegate performSelector:@selector(scrollViewDidScroll:) withObject:self];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if ([self.delegate respondsToSelector:@selector(scrollViewWillBeginDragging:)])
    {
        [self.delegate performSelector:@selector(scrollViewWillBeginDragging:) withObject:self];
    }
    
    [self loadPages];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if ([self.delegate respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)])
    {
        [self.delegate scrollViewDidEndDragging:self willDecelerate:decelerate];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self pageIndexChanged];
    
    if ([self.delegate respondsToSelector:@selector(scrollViewDidEndDecelerating:)])
    {
        [self.delegate performSelector:@selector(scrollViewDidEndDecelerating:) withObject:self];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
	[self pageIndexChanged];
    
    if ([self.delegate respondsToSelector:@selector(scrollViewDidEndScrollingAnimation:)])
    {
        [self.delegate performSelector:@selector(scrollViewDidEndScrollingAnimation:) withObject:self];
    }
}


- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView   // called on finger up as we are moving
{
    if ([self.delegate respondsToSelector:@selector(scrollViewWillBeginDecelerating:)])
    {
        [self.delegate performSelector:@selector(scrollViewWillBeginDecelerating:) withObject:self];
    }
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView
{
    if ([self.delegate respondsToSelector:@selector(scrollViewDidScrollToTop:)])
    {
        [self.delegate performSelector:@selector(scrollViewDidScrollToTop:) withObject:self];
    }
}


- (void)pageIndexChanged
{
    NSInteger newPageIndex = NSNotFound;
    
    [self loadPages];
    
    if (_direction == ZBScrollViewDirectionHorizontal)
    {
        CGFloat pageWidth = self.pageSizeWithPadding.width;
        newPageIndex =  newPageIndex = floor(self.contentOffset.x) /
        ((floor(pageWidth)==0)?(1):(floor(pageWidth)));
	}
    else if (_direction == ZBScrollViewDirectionVertical)
    {
        CGFloat pageHeight = self.pageSizeWithPadding.height;
        newPageIndex = newPageIndex = floor(self.contentOffset.y) /
        ((floor(pageHeight)==0)?(1):(floor(pageHeight)));
    }
    
    if (newPageIndex != _currentPageIndex)
    {
        _currentPageIndex = newPageIndex;
        if ([self.delegate respondsToSelector:@selector(zbScrollView:pageChanged:)] &&
            [_indexPaths count] > 0)
        {
            [self.delegate zbScrollView:self
                               pageChanged:[self indexPathForIndex:_currentPageIndex]];
        }
	}
}



#pragma mark -
#pragma mark Page Frame calculations

- (void)setPagePadding:(CGFloat)pagePadding
{
    if (_pagePadding != pagePadding)
    {
        _pagePadding = pagePadding;
        
        CGRect frame = self.frame;
        if (_direction == ZBScrollViewDirectionHorizontal)
        {
            frame.origin.x -= self.pagePadding;
            frame.size.width += (2 * self.pagePadding);
        }
        else if (_direction == ZBScrollViewDirectionVertical)
        {
            frame.origin.y -= self.pagePadding;
            frame.size.height += (2 * self.pagePadding);
        }
        
        [super setFrame:frame];
        
        [self reloadData];
    }
}


- (void)updateContentSize
{
    if (_direction == ZBScrollViewDirectionHorizontal)
    {
        self.contentSize = CGSizeMake(self.pageSizeWithPadding.width * [self pagesCount],
                                      self.pageSizeWithPadding.height);
	}
    else if (_direction == ZBScrollViewDirectionVertical)
    {
        self.contentSize = CGSizeMake(self.pageSizeWithPadding.width,
                                      self.pageSizeWithPadding.height* [self pagesCount]);
    }
}


- (void)updateFrameForAvailablePages
{
	for (UIView *page in self.storedPages)
	{
		if ((NSNull*)page != [NSNull null])
        {
            page.frame = [self frameForPageAtIndex:page.tag
                                          withSize:page.frame.size];
        }
	}
}

- (CGRect)frameForPageAtIndex:(NSUInteger)index withSize:(CGSize)size
{
    
    CGRect pageFrame = CGRectMake(self.bounds.origin.x,
                                  self.bounds.origin.y,
                                  size.width,
                                  size.height);
    
    
    if (_direction == ZBScrollViewDirectionHorizontal)
    {
        pageFrame.origin.x = (self.pageSizeWithPadding.width * index) + self.pagePadding;
        pageFrame.origin.y = 0;
    }
    else if (_direction == ZBScrollViewDirectionVertical)
    {
        pageFrame.origin.x = 0;
        pageFrame.origin.y = (self.pageSizeWithPadding.height * index) + self.pagePadding;
    }
    
    
    return pageFrame;
}



- (void)setDirection:(ZBScrollViewDirection)direction
{
    if (_direction != direction)
    {
        _direction = direction;
        [self reloadData];
    }
}

- (CGSize)pageSizeWithPadding
{
    
    if ([_indexPaths count] == 0)
    {
        
        _pageSizeWithPadding = CGSizeZero;
        
        return _pageSizeWithPadding;
    }
    
    CGSize size = _pageSizeWithPadding;
    if (CGSizeEqualToSize(size,CGSizeZero))
    {
        UIView *page = [self.storedPages lastObject];
        if (page == nil)
        {
            page = [self askDataSourceForPageAtIndex:0];
        }
        if (page != nil)
        {
            size = page.bounds.size;
            
            if (_direction == ZBScrollViewDirectionHorizontal)
            {
                size = CGSizeMake(size.width+(2*self.pagePadding),size.height);
            }
            else if (_direction == ZBScrollViewDirectionVertical)
            {
                size = CGSizeMake(size.width,size.height+(2*self.pagePadding));
            }
            
            _pageSizeWithPadding = size;
        }
    }
    
    
    return _pageSizeWithPadding;
}




#pragma mark -
#pragma mark Count & hold the data Source



- (NSUInteger)sectionCount
{
	if ([self.dataSource respondsToSelector:@selector(numberOfSectionsInzbScrollView:)])
    {
        return [self.dataSource numberOfSectionsInZBScrollView:self];
    }
    return 1;
}

- (NSUInteger)pagesCount {
    
	return [_indexPaths count];
	
}


- (void)setIndexPaths
{
	[_indexPaths removeAllObjects];
    

    NSUInteger rowsInSection = 1;
    //if ([self.dataSource respondsToSelector:@selector(zbScrollView:numberOfPagesInSection:)])
    if([self.dataSource respondsToSelector:@selector(GetNumberOfPagesFromZBScrollView:)])
    {
			//rowsInSection = [self.dataSource zbScrollView:self numberOfPagesInSection:section];
        rowsInSection=[self.dataSource GetNumberOfPagesFromZBScrollView:self];
    }
		
    for (int row = 0; row < rowsInSection; row++)
    {
			//NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
        [_indexPaths addObject:row];
    }
	//}
}

- (NSIndexPath*)indexPathForIndex:(NSInteger)index
{
    if (index < [_indexPaths count] &&
        index >= 0)
    {
        return [_indexPaths objectAtIndex:index];
    }
    
    return nil;
}


@end
