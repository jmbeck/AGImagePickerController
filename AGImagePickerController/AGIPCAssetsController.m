//
//  AGIPCAssetsController.m
//  AGImagePickerController
//
//  Created by Artur Grigor on 17.02.2012.
//  Copyright (c) 2012 Artur Grigor. All rights reserved.
//  
//  For the full copyright and license information, please view the LICENSE
//  file that was distributed with this source code.
//  

#import "AGIPCAssetsController.h"

#import "AGImagePickerController.h"
#import "AGImagePickerController+Constants.h"

#import "AGIPCGridCell.h"
#import "AGIPCToolbarItem.h"

@interface AGIPCAssetsController ()

@property (nonatomic, retain) NSMutableArray *assets;
@property (readonly) AGImagePickerController *imagePickerController;
@property (retain, nonatomic) IBOutlet UIView *customToolbar;
@property (retain, nonatomic) IBOutlet UIScrollView *customToolbarScroll;


@end


@interface AGIPCAssetsController (Private)

- (void)changeSelectionInformation;

- (void)createNotifications;
- (void)destroyNotifications;

- (void)didChangeLibrary:(NSNotification *)notification;

- (BOOL)toolbarHidden;

- (void)loadAssets;
- (void)reloadData;

- (void)setupToolbarItems;

- (NSArray *)itemsForRowAtIndexPath:(NSIndexPath *)indexPath;

- (void)doneAction:(id)sender;
- (void)selectAllAction:(id)sender;
- (void)deselectAllAction:(id)sender;
- (void)customBarButtonItemAction:(id)sender;

@end

@implementation AGIPCAssetsController

#pragma mark - Properties
@synthesize customToolbar;
@synthesize customToolbarScroll;
@synthesize toolbarAssets, toolbarButtons;

@synthesize tableView, assetsGroup, assets;

- (BOOL)toolbarHidden
{
    if (self.imagePickerController.toolbarItemsForSelection != nil) {
        return !(self.imagePickerController.toolbarItemsForSelection.count > 0);
    } else {
        return NO;
    }
}

- (void)setAssetsGroup:(ALAssetsGroup *)theAssetsGroup
{
    @synchronized (self)
    {
        if (assetsGroup != theAssetsGroup)
        {
            [assetsGroup release];
            assetsGroup = [theAssetsGroup retain];
            [assetsGroup setAssetsFilter:[ALAssetsFilter allPhotos]];

            [self reloadData];
        }
    }
}

- (ALAssetsGroup *)assetsGroup
{
    ALAssetsGroup *ret = nil;
    
    @synchronized (self)
    {
        ret = [[assetsGroup retain] autorelease];
    }
    
    return ret;
}

- (NSArray *)selectedAssets
{
    NSMutableArray *selectedAssets = [NSMutableArray array];
    
	for (AGIPCGridItem *gridItem in self.assets) 
    {		
		if (gridItem.selected)
        {	
			[selectedAssets addObject:gridItem.asset];
		}
	}
    
    return selectedAssets;
}

- (AGImagePickerController *)imagePickerController
{
    return ((AGImagePickerController *)self.navigationController);
}

#pragma mark - Object Lifecycle

- (void)dealloc
{
    [tableView release];
    [assetsGroup release];
    [assets release];
    
    [super dealloc];
}

- (id)initWithAssetsGroup:(ALAssetsGroup *)theAssetsGroup
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        self = [super initWithNibName:@"AGIPCAssetsController_iPhone" bundle:nil];
    } else {
        self = [super initWithNibName:@"AGIPCAssetsController_iPad" bundle:nil];
    }
    if (self)
    {
        assets = [[NSMutableArray alloc] init];
        self.assetsGroup = theAssetsGroup;
        self.title = NSLocalizedStringWithDefaultValue(@"AGIPC.Loading", nil, [NSBundle mainBundle], @"Loading...", nil);
    }
    
    return self;
}

#pragma mark - UITableViewDataSource Methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    double numberOfAssets = (double)self.assetsGroup.numberOfAssets;
    return ceil(numberOfAssets / [AGImagePickerController numberOfItemsPerRow]);
}

- (NSArray *)itemsForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:[AGImagePickerController numberOfItemsPerRow]];
    
    NSUInteger startIndex = indexPath.row * [AGImagePickerController numberOfItemsPerRow], 
                 endIndex = startIndex + [AGImagePickerController numberOfItemsPerRow] - 1;
    if (startIndex < self.assets.count)
    {
        if (endIndex > self.assets.count - 1)
            endIndex = self.assets.count - 1;
        
        for (NSUInteger i = startIndex; i <= endIndex; i++)
        {
            [items addObject:[self.assets objectAtIndex:i]];
        }
    }
    
    return items;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    AGIPCGridCell *cell = (AGIPCGridCell *)[self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) 
    {		       
        cell = [[[AGIPCGridCell alloc] initWithItems:[self itemsForRowAtIndexPath:indexPath] reuseIdentifier:CellIdentifier] autorelease];
    }	
	else 
    {		
		cell.items = [self itemsForRowAtIndexPath:indexPath];
	}
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGRect itemRect = [AGImagePickerController itemRect];
    return itemRect.size.height + itemRect.origin.y;
}

#pragma mark - View Lifecycle

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}

- (void)viewWillAppear:(BOOL)animated
{
    // Reset the number of selections
    [AGIPCGridItem performSelector:@selector(resetNumberOfSelections)];
    
    [super viewWillAppear:animated];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.toolbarAssets = [NSMutableArray new];
    self.toolbarButtons = [NSMutableArray new];
    
    // Fullscreen
    if (self.imagePickerController.shouldChangeStatusBarStyle) {
        self.wantsFullScreenLayout = YES;
    }
    
    // Setup Notifications
    [self createNotifications];
    
    // Start loading the assets
    [self loadAssets];
    
    // Navigation Bar Items
    UIBarButtonItem* cancelButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelAction:)];
    self.navigationItem.rightBarButtonItem = cancelButtonItem;
    [cancelButtonItem release];
    
    UIBarButtonItem *doneButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneAction:)];
    doneButtonItem.enabled = NO;
	self.navigationItem.leftBarButtonItem = doneButtonItem;
    [doneButtonItem release];
    
    // Setup toolbar items
    [self setupCustomToolbar];
    self.navigationController.toolbarHidden = YES;
    
    self.customToolbarScroll.exclusiveTouch = YES;
    self.customToolbarScroll.userInteractionEnabled = YES;
    self.customToolbarScroll.canCancelContentTouches = YES;
    self.customToolbarScroll.delaysContentTouches = YES;

}

- (void)viewDidUnload
{
    [self setCustomToolbar:nil];
    [self setCustomToolbarScroll:nil];
    [super viewDidUnload];
    
    // Destroy Notifications
    [self destroyNotifications];
}

#pragma mark - Private

- (void)setupCustomToolbar {
    int offsetY = 374;
    self.customToolbar.frame = CGRectMake(0, 
                                            offsetY,
                                            self.view.frame.size.width,
                                            self.customToolbar.frame.size.height);
}

- (void)loadAssets
{
    [self.assets removeAllObjects];
    
    __block AGIPCAssetsController *blockSelf = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        @autoreleasepool {
            [blockSelf.assetsGroup enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                
                if (result == nil) 
                {
                    return;
                }
                
                AGIPCGridItem *gridItem = [[AGIPCGridItem alloc] initWithAsset:result andDelegate:blockSelf];
                if ( blockSelf.imagePickerController.selection != nil && 
                    [blockSelf.imagePickerController.selection containsObject:result])
                {
                    gridItem.selected = YES;
                }
                [blockSelf.assets addObject:gridItem];
                [gridItem release];
            }];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [blockSelf reloadData];
            
        });
        
    });
}

- (void)reloadData
{
    // Don't display the select button until all the assets are loaded.
//    [self.navigationController setToolbarHidden:[self toolbarHidden] animated:YES];
    
    [self.tableView reloadData];
    [self setTitle:@"Select Items"];
    [self changeSelectionInformation];
    
    NSInteger totalRows = [self.tableView numberOfRowsInSection:0];
    
    //Prevents crash if totalRows = 0 (when the album is empty). 
    if (totalRows > 0) {

        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:totalRows-1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:NO];
    }
}

- (void)cancelAction:(id)sender
{
    [self dismissModalViewControllerAnimated:YES];
}

- (void)doneAction:(id)sender
{
    [self.imagePickerController performSelector:@selector(didFinishPickingAssets:) withObject:self.selectedAssets];
}

- (void)selectAllAction:(id)sender
{
    for (AGIPCGridItem *gridItem in self.assets) {
        gridItem.selected = YES;
    }
}

- (void)deselectAllAction:(id)sender
{
    for (AGIPCGridItem *gridItem in self.assets) {
        gridItem.selected = NO;
    }
}

- (void)customBarButtonItemAction:(id)sender
{
    for (id item in self.imagePickerController.toolbarItemsForSelection)
    {
        NSAssert([item isKindOfClass:[AGIPCToolbarItem class]], @"Item is not a instance of AGIPCToolbarItem.");
        
        if (((AGIPCToolbarItem *)item).barButtonItem == sender)
        {
            if (((AGIPCToolbarItem *)item).assetIsSelectedBlock) {
                
                NSUInteger idx = 0;
                for (AGIPCGridItem *obj in self.assets) {
                    obj.selected = ((AGIPCToolbarItem *)item).assetIsSelectedBlock(idx, ((AGIPCGridItem *)obj).asset);
                    idx++;
                }
                
            }
        }
    }
}

- (void)changeSelectionInformation
{
    if (self.imagePickerController.shouldDisplaySelectionInformation) {
        self.navigationController.navigationBar.topItem.prompt = [NSString stringWithFormat:@"(%d/%d)", [AGIPCGridItem numberOfSelections], self.assets.count];
    }
}

#pragma mark - AGGridItemDelegate Methods

- (void)agGridItem:(AGIPCGridItem *)gridItem didChangeNumberOfSelections:(NSNumber *)numberOfSelections
{
    self.navigationItem.leftBarButtonItem.enabled = (numberOfSelections.unsignedIntegerValue > 0);
    [self changeSelectionInformation];
}

- (BOOL)agGridItemCanSelect:(AGIPCGridItem *)gridItem
{
    if (self.imagePickerController.maximumNumberOfPhotos > 0)
        return ([AGIPCGridItem numberOfSelections] < self.imagePickerController.maximumNumberOfPhotos);
    else
        return YES;
}

#pragma mark - Notifications

- (void)createNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(didChangeLibrary:) 
                                                 name:ALAssetsLibraryChangedNotification 
                                               object:[AGImagePickerController defaultAssetsLibrary]];
}

- (void)destroyNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:ALAssetsLibraryChangedNotification 
                                                  object:[AGImagePickerController defaultAssetsLibrary]];
}

- (void)didChangeLibrary:(NSNotification *)notification
{
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)agGridItem:(AGIPCGridItem *)gridItem didChangeSelectionState:(NSNumber *)selected {
    
    if(selected.boolValue) {
        // Grab the thumbnail from the gridItem
        UIButton* previewImageBtn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        previewImageBtn.tag = [self.assets indexOfObject:gridItem];
        UIImage* image = [UIImage imageWithCGImage:[gridItem.asset thumbnail]];
        
        previewImageBtn.transform = CGAffineTransformScale(previewImageBtn.transform, 0.5, 0.5); // Scale down to 1/2 for retina
        [previewImageBtn setImage:image forState:UIControlStateNormal];
        
        // Offset to the right based on the number of images
        int offsetX = 10 + (self.selectedAssets.count - 1) * 90;
        CGRect previewFrame = previewImageBtn.frame;
 
        previewImageBtn.frame = CGRectMake(offsetX, 0,
                                           image.size.width/2, image.size.height/2);
        
        NSString* deleteBtnPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingString:@"/delete_button@2x.png"];
        UIImage* deleteBtnImage = [UIImage imageWithContentsOfFile:deleteBtnPath];
        UIImageView* deleteBtnImageView = [UIImageView new];
        deleteBtnImageView.image = deleteBtnImage;
        deleteBtnImageView.frame = CGRectMake(117,14,
                                               deleteBtnImage.size.width, deleteBtnImage.size.height);
        deleteBtnImageView.transform = CGAffineTransformScale(deleteBtnImageView.transform, 2, 2);
        
        [previewImageBtn addSubview:deleteBtnImageView];
        [previewImageBtn addTarget:self action:@selector(deleteBtnTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        int contentWidth = self.selectedAssets.count * 90;
        self.customToolbarScroll.contentSize = CGSizeMake(contentWidth, previewFrame.size.height);
        [self.customToolbarScroll addSubview:previewImageBtn];
        [self.toolbarAssets addObject:gridItem.asset];
        [self.toolbarButtons addObject:previewImageBtn];
        
        int contentOffsetX = contentWidth - self.customToolbarScroll.frame.size.width;
        if(contentOffsetX > 0) {
            [UIView beginAnimations:nil context:nil];
            [UIView setAnimationDuration:0.5];
            self.customToolbarScroll.contentOffset = CGPointMake(contentOffsetX, 0);
            [UIView commitAnimations];
        }
    } else {
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:0.5];
        
        // Remove the UIImageView from the scrollview and shift all the rest down.
        int deselectedIndex = 0;
        for(ALAsset* asset in self.toolbarAssets) {
            if([asset isEqual:gridItem.asset]) {
                break;
            }
            deselectedIndex++;
        }
        
        int i = 0;
        int removeButtonIndex = -1;
        UIButton* removeButton = nil;
        
        for(UIButton* button in self.toolbarButtons) {
            if(i < deselectedIndex) {
                i++;
                continue;
            }
            
            if(i == deselectedIndex) {
                removeButtonIndex = i;
                removeButton = button;
                break;
            }
        }
        
        [self.toolbarAssets removeObjectAtIndex:removeButtonIndex];
        [self.toolbarButtons removeObjectAtIndex:removeButtonIndex];
        [removeButton removeFromSuperview];
        
        for(int i = removeButtonIndex; i < self.toolbarButtons.count; i++) {
            UIButton* button = [self.toolbarButtons objectAtIndex:i];
            CGRect buttonFrame = button.frame;
            button.frame = CGRectMake(buttonFrame.origin.x - 90, buttonFrame.origin.y, buttonFrame.size.width, buttonFrame.size.height);
        }
        
        int contentWidth = self.selectedAssets.count * 90;
        self.customToolbarScroll.contentSize = CGSizeMake(contentWidth, customToolbarScroll.contentSize.height);
        
        [UIView commitAnimations];
    }
}

- (IBAction)deleteBtnTapped:(id)sender {
    AGIPCGridItem* item = [self.assets objectAtIndex:[sender tag]];
    [item setSelected:NO];
}

@end