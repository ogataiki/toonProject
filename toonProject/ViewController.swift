import UIKit
import GPUImage

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var detailSlider: UISlider!
    
    @IBOutlet weak var edgeSwitch: UISwitch!
    @IBOutlet weak var edgeSlider: UISlider!
    
    @IBOutlet weak var levelSegmented: UISegmentedControl!
    
    @IBOutlet weak var imageSelectSeg: UISegmentedControl!
    
    let activityIndicatorView = UIActivityIndicatorView();

    
    let shaderFilter = GPUImageFilter(fragmentShaderFromFile: "toon");
    let gaussianFilter = GPUImageGaussianBlurFilter();

    var sourceImage: UIImage? = nil;
    var filteredImage: UIImage? = nil;
    var isEdge = false;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
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
        
        // Cancelボタン
        let cancelAction: UIAlertAction = UIAlertAction(title: "cancel", style: UIAlertActionStyle.Cancel, handler:{
            (action: UIAlertAction) -> Void in
        })
        
        alert.addAction(cancelAction);
        alert.addAction(cameraAction);
        alert.addAction(movieAction);
        alert.addAction(libraryAction);
        
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
            
            self.shaderFilter.setFloat(GLfloat(image.size.width), forUniformName: "imageWidth");
            self.shaderFilter.setFloat(GLfloat(image.size.height), forUniformName: "imageHeight");
            self.shaderFilter.setFloat(GLfloat((self.edgeSwitch.on) ? 1.0 : 0.0), forUniformName: "edge");
            self.shaderFilter.setFloat(GLfloat(self.edgeSlider.value), forUniformName: "edgeValue");
            self.shaderFilter.setFloat(GLfloat(self.levelSegmented.selectedSegmentIndex), forUniformName: "levelValue");
            
            gaussianFilter.blurRadiusInPixels = CGFloat(detailSlider.value);
            if let out = gaussianFilter.imageByFilteringImage(image) {
                if let o = self.shaderFilter.imageByFilteringImage(out) {
                    self.filteredImage = o;
                    self.imageSelectSeg.selectedSegmentIndex = 1;
                    
                    self.imageView.image = o;
                    
                    self.activityIndicatorView.stopAnimating();
                    self.menuEnabled(true);
                    return;
                }
            }
            
            self.filteredImage = nil;
            self.imageView.image = image;
        }
        
        self.activityIndicatorView.stopAnimating();
        self.menuEnabled(true);
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
    
    // 写真を選択した時に呼ばれる
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        
        picker.dismissViewControllerAnimated(true, completion: nil);

        if info[UIImagePickerControllerOriginalImage] != nil {
            
            // ソースイメージ更新
            self.sourceImage = info[UIImagePickerControllerOriginalImage] as? UIImage;
            
            // フィルタかける
            execToonFilter();
        }
    }
}

