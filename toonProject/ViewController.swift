import UIKit
import GPUImage
import MobileCoreServices

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIScrollViewDelegate {

    @IBOutlet weak var imageScrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var toolView: UIView!
    
    @IBOutlet weak var detailSlider: UISlider!
    
    @IBOutlet weak var edgeSwitch: UISwitch!
    @IBOutlet weak var edgeSlider: UISlider!
    
    @IBOutlet weak var levelSegmented: UISegmentedControl!
    
    @IBOutlet weak var imageSelectSeg: UISegmentedControl!
    
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    let activityIndicatorView = UIActivityIndicatorView();

    let shaderFilter = GPUImageFilter(fragmentShaderFromFile: "toon");
    let gaussianFilter = GPUImageGaussianBlurFilter();

    var sourceImage: UIImage? = nil;
    var filteredImage: UIImage? = nil;
    var isEdge = false;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        toolView.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.8);
        
        imageScrollView.delegate = self;
        if let size = imageView.image?.size {
            // imageViewのサイズがscrollView内に収まるように調整
            let wrate = imageScrollView.frame.width / size.width
            let hrate = imageScrollView.frame.height / size.height
            let rate = min(wrate, hrate, 1)
            imageView.frame.size = CGSizeMake(size.width * rate, size.height * rate)
            
            // contentSizeを画像サイズに設定
            imageScrollView.contentSize = imageView.frame.size
            // 初期表示のためcontentInsetを更新
            updateScrollInset()
        }

        levelSegmented.selectedSegmentIndex = 1;
        
        activityIndicatorView.frame = imageView.frame;
        activityIndicatorView.center = CGPointMake(self.view.frame.size.width*0.5, imageView.center.y);
        activityIndicatorView.hidesWhenStopped = false;
        activityIndicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.Gray;
        activityIndicatorView.color = UIColor.cyanColor();
        activityIndicatorView.hidesWhenStopped = true;
        activityIndicatorView.stopAnimating();
        self.view.addSubview(activityIndicatorView);
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func menuEnabled(value: Bool) {
        detailSlider.enabled = value;
        edgeSwitch.enabled = value;
        edgeSlider.enabled = value;
        levelSegmented.enabled = value;
        imageSelectSeg.enabled = value;
        saveButton.enabled = value;
    }

    @IBAction func cameraAction(sender: UIBarButtonItem) {
        
        if activityIndicatorView.isAnimating() {
            return;
        }

        let alert: UIAlertController = UIAlertController(title: "写真を選択"
            , message: nil
            , preferredStyle:  UIAlertControllerStyle.ActionSheet);
        
        // Defaultボタン
        let cameraAction: UIAlertAction = UIAlertAction(title: "カメラで写真撮影", style: UIAlertActionStyle.Default, handler:{
            (action: UIAlertAction) -> Void in
            self.pickImageFromCamera();
        })
        let movieAction: UIAlertAction = UIAlertAction(title: "カメラで動画撮影", style: UIAlertActionStyle.Default, handler:{
            (action: UIAlertAction) -> Void in
            self.pickMovieFromCamera();
        })
        let libraryAction: UIAlertAction = UIAlertAction(title: "写真を選択", style: UIAlertActionStyle.Default, handler:{
            (action: UIAlertAction) -> Void in
            self.pickImageFromLibrary();
        })
        let libraryMovieAction: UIAlertAction = UIAlertAction(title: "動画を選択", style: UIAlertActionStyle.Default, handler:{
            (action: UIAlertAction) -> Void in
            self.pickMovieFromLibrary();
        })
        
        // Cancelボタン
        let cancelAction: UIAlertAction = UIAlertAction(title: "cancel", style: UIAlertActionStyle.Cancel, handler:{
            (action: UIAlertAction) -> Void in
        })
        
        alert.addAction(cancelAction);
        alert.addAction(cameraAction);
        alert.addAction(movieAction);
        alert.addAction(libraryAction);
        alert.addAction(libraryMovieAction);
        
        presentViewController(alert, animated: true, completion: nil)
    }
    
    
    
    @IBAction func detailValueChange(sender: AnyObject) {
        execToonFilter();
    }

    @IBAction func edgeChange(sender: UISwitch) {
        execToonFilter();
    }
    
    @IBAction func edgeValueChange(sender: UISlider) {
        execToonFilter();
    }
    
    @IBAction func levelChange(sender: UISegmentedControl) {
        execToonFilter();
    }
    
    @IBAction func imageSourceChange(sender: UISegmentedControl) {
        if(sender.selectedSegmentIndex == 0) {
            if let source = sourceImage {
                self.imageView.image = source;
            }
        }
        else {
            if let out = self.filteredImage {
                self.imageView.image = out;
            }            
        }
    }
    
    @IBAction func saveAction(sender: UIBarButtonItem) {
        if let i = self.filteredImage {
            UIImageWriteToSavedPhotosAlbum(i, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil);
        }
    }
    func image(image: UIImage, didFinishSavingWithError error: NSError!, contextInfo: UnsafeMutablePointer<Void>) {
        if error != nil {
            //プライバシー設定不許可など書き込み失敗時は -3310 (ALAssetsLibraryDataUnavailableError)
            print(error.code)
        }
        else {
            let alert: UIAlertController = UIAlertController(title: "画像を保存しました"
                , message: nil
                , preferredStyle:  UIAlertControllerStyle.Alert);
            // Defaultボタン
            let okAction: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler:{
                (action: UIAlertAction) -> Void in
            })
            alert.addAction(okAction);
            presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    func execToonFilter() {
        
        menuEnabled(false);
        activityIndicatorView.startAnimating()
        NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.0));
        
        // バックグラウンドで処理すると途中で処理がおかしくなってへんな画像が生成されることがある。
        // フィルタかける
        if let origImage = self.sourceImage {
            
            // 撮影時の向き反映
            var image = origImage;
            
            // 処理速度向上のためサイズを縮小 & 撮影時の向きを反映
            let baseWidth: CGFloat = 1600;
            // 長い方の辺を見て比率を決める
            let ratio: CGFloat;
            if image.size.width >= image.size.height {
                ratio = baseWidth / image.size.width;
            }
            else {
                ratio = baseWidth / image.size.height;
            }
            let newSize = CGSize(width: (image.size.width * ratio), height: (image.size.height * ratio));
            UIGraphicsBeginImageContext(newSize);
            image.drawInRect(CGRectMake(0, 0, newSize.width, newSize.height));
            image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            if let out = toonFilter(image.size).imageByFilteringImage(image) {
                self.filteredImage = out;
                self.imageSelectSeg.selectedSegmentIndex = 1;
                
                self.imageView.image = out;
                
                self.activityIndicatorView.stopAnimating();
                self.menuEnabled(true);
                return;
            }
            
            self.filteredImage = nil;
            self.imageView.image = image;
        }
        
        self.activityIndicatorView.stopAnimating();
        self.menuEnabled(true);
    }
    
    func execToonFilterMovie(url: NSURL) {
        
        menuEnabled(false);
        activityIndicatorView.startAnimating()
        NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.0));
        
        //表示するためのviewを用意
        let gpuImageView = GPUImageView(frame: self.imageView.frame);
        self.view.addSubview(gpuImageView);
        
        let group = toonFilterGpuImageView(gpuImageView);
        
        let movieFile = GPUImageMovie(URL: url);
        movieFile.playAtActualSpeed = true;
        movieFile.addTarget(group);
        movieFile.startProcessing();

        /*
        let asset = AVURLAsset(URL: url);
        let videoTracks = asset.tracksWithMediaType(AVMediaTypeVideo);
        let videoTrack = videoTracks[0];
        var exportUrl: NSURL?;
        if let dir : NSString = NSSearchPathForDirectoriesInDomains( NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.AllDomainsMask, true ).first {
            exportUrl = NSURL(fileURLWithPath: dir.stringByAppendingPathComponent("tmp.mp4"));
        }
        let movieWriter = GPUImageMovieWriter(movieURL: exportUrl, size: videoTrack.naturalSize);
        
        group.addTarget(movieWriter);
 
        movieWriter.shouldPassthroughAudio = true;
        
        movieFile.audioEncodingTarget = movieWriter;
        movieFile.enableSynchronizedEncodingUsingMovieWriter(movieWriter);
 
        var alreadyRecordComplate = false;
        
        movieWriter.completionBlock = {() in
            if alreadyRecordComplate == false {
                alreadyRecordComplate = true;
                
                movieWriter.finishRecordingWithCompletionHandler({
                    group.removeTarget(movieWriter);
                })
            }
        }
        
        movieWriter.failureBlock = { (error: NSError!) in
        }
        
        movieWriter.startRecording();
         */

        self.activityIndicatorView.stopAnimating();
        self.menuEnabled(true);
    }
    
    func toonFilter(size: CGSize) -> GPUImageFilterGroup {
        
        let gaussian = GPUImageGaussianBlurFilter();
        gaussian.blurRadiusInPixels = CGFloat(detailSlider.value);

        let toonShader = GPUImageFilter(fragmentShaderFromFile: "toon");
        toonShader.setFloat(GLfloat(size.width), forUniformName: "imageWidth");
        toonShader.setFloat(GLfloat(size.height), forUniformName: "imageHeight");
        toonShader.setFloat(GLfloat((self.edgeSwitch.on) ? 1.0 : 0.0), forUniformName: "edge");
        toonShader.setFloat(GLfloat(self.edgeSlider.value), forUniformName: "edgeValue");
        toonShader.setFloat(GLfloat(self.levelSegmented.selectedSegmentIndex), forUniformName: "levelValue");
        
        let group = GPUImageFilterGroup();
        group.addFilter(gaussian);
        group.addFilter(toonShader);
        group.initialFilters = [gaussian];
        group.terminalFilter = toonShader;
        gaussian.addTarget(toonShader);
        
        group.forceProcessingAtSize(size);

        return group;
    }
    
    func toonFilterGpuImageView(gpuimageview: GPUImageView) -> GPUImageFilterGroup {
        
        let group = toonFilter(gpuimageview.frame.size);
        group.addTarget(gpuimageview);

        return group;
    }


    
    // 写真を撮ってそれを選択
    func pickImageFromCamera() {
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera) {
            let controller = UIImagePickerController()
            controller.delegate = self;
            controller.sourceType = UIImagePickerControllerSourceType.Camera;
            self.presentViewController(controller, animated: true, completion: nil);
        }
    }

    func pickMovieFromCamera() {
    }

    // ライブラリから写真を選択する
    func pickImageFromLibrary() {
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.PhotoLibrary) {
            let controller = UIImagePickerController();
            controller.delegate = self;
            controller.sourceType = UIImagePickerControllerSourceType.PhotoLibrary;
            self.presentViewController(controller, animated: true, completion: nil);
        }
    }
    
    // ライブラリから動画を選択する
    func pickMovieFromLibrary() {
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.PhotoLibrary) {
            let controller = UIImagePickerController()
            controller.delegate = self
            controller.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
            controller.mediaTypes = [kUTTypeMovie as String];
            controller.allowsEditing = false;
            self.presentViewController(controller, animated: true, completion: nil)
        }
    }

    
    // 写真を選択した時に呼ばれる
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        
        picker.dismissViewControllerAnimated(true, completion: nil);

        let mediaType: CFString = info[UIImagePickerControllerMediaType] as! CFString;
        if mediaType == kUTTypeMovie {
            
            let url = info[UIImagePickerControllerMediaURL] as! NSURL;
            execToonFilterMovie(url);
        }
        
        if info[UIImagePickerControllerOriginalImage] != nil {
            
            // ソースイメージ更新
            self.sourceImage = info[UIImagePickerControllerOriginalImage] as? UIImage;
            
            // フィルタかける
            execToonFilter();
        }
    }
    
    
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        // ズームのために要指定
        return imageView
    }
    
    func scrollViewDidZoom(scrollView: UIScrollView) {
        // ズームのタイミングでcontentInsetを更新
        updateScrollInset()
    }
    
    private func updateScrollInset() {
        // imageViewの大きさからcontentInsetを再計算
        // なお、0を下回らないようにする
        imageScrollView.contentInset = UIEdgeInsetsMake(
            max((imageScrollView.frame.height - imageView.frame.height)/2, 0),
            max((imageScrollView.frame.width - imageView.frame.width)/2, 0),
            0,
            0
        );
    }
}

