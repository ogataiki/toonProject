import UIKit
import GPUImage

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var edgeSwitch: UISwitch!
    @IBOutlet weak var edgeSlider: UISlider!
    
    @IBOutlet weak var levelSegmented: UISegmentedControl!
    
    @IBOutlet weak var imageSelectSeg: UISegmentedControl!
    
    let shaderFilter = GPUImageFilter(fragmentShaderFromFile: "toon");
    var sourceImage: UIImage? = nil;
    var filteredImage: UIImage? = nil;
    var isEdge = false;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        levelSegmented.selectedSegmentIndex = 1;
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func cameraAction(sender: UIBarButtonItem) {
        
        let alert: UIAlertController = UIAlertController(title: "写真を選択"
            , message: nil
            , preferredStyle:  UIAlertControllerStyle.ActionSheet);
        
        // Defaultボタン
        let cameraAction: UIAlertAction = UIAlertAction(title: "カメラで撮影", style: UIAlertActionStyle.Default, handler:{
            (action: UIAlertAction) -> Void in
            self.pickImageFromCamera();
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
        alert.addAction(libraryAction);
        
        presentViewController(alert, animated: true, completion: nil)
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
        // フィルタかける
        if let image = self.sourceImage {
            
            self.shaderFilter.setFloat(GLfloat(image.size.width), forUniformName: "imageWidth");
            self.shaderFilter.setFloat(GLfloat(image.size.height), forUniformName: "imageHeight");
            self.shaderFilter.setFloat(GLfloat((edgeSwitch.on) ? 1.0 : 0.0), forUniformName: "edge");
            self.shaderFilter.setFloat(GLfloat(edgeSlider.value), forUniformName: "edgeValue");
            self.shaderFilter.setFloat(GLfloat(levelSegmented.selectedSegmentIndex), forUniformName: "levelValue");
            if let out = self.shaderFilter.imageByFilteringImage(image) {
                let gaussianFilter = GPUImageGaussianBlurFilter();
                if let o = gaussianFilter.imageByFilteringImage(out) {
                    filteredImage = o;
                    self.imageView.image = o;
                    imageSelectSeg.selectedSegmentIndex = 1;
                    return;
                }
            }
            filteredImage = nil;
            self.imageView.image = image;
        }
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

