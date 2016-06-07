import UIKit
import GPUImage

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var edgeSwitch: UISwitch!
    @IBOutlet weak var edgeSlider: UISlider!
    
    let shaderFilter = GPUImageFilter(fragmentShaderFromFile: "toon");
    var sourceImage: UIImage? = nil;
    var isEdge = false;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
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
            (action: UIAlertAction!) -> Void in
            self.pickImageFromCamera();
        })
        let libraryAction: UIAlertAction = UIAlertAction(title: "写真を選択", style: UIAlertActionStyle.Default, handler:{
            (action: UIAlertAction!) -> Void in
            self.pickImageFromLibrary();
        })
        
        // Cancelボタン
        let cancelAction: UIAlertAction = UIAlertAction(title: "cancel", style: UIAlertActionStyle.Cancel, handler:{
            (action: UIAlertAction!) -> Void in
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
    
    func execToonFilter() {
        // フィルタかける
        if let image = self.sourceImage {
            self.shaderFilter.setFloat(GLfloat(image.size.width), forUniformName: "imageWidth");
            self.shaderFilter.setFloat(GLfloat(image.size.height), forUniformName: "imageHeight");
            self.shaderFilter.setFloat(GLfloat((edgeSwitch.on) ? 1.0 : 0.0), forUniformName: "edge");
            self.shaderFilter.setFloat(GLfloat(edgeSlider.value), forUniformName: "edgeValue");
            if let out = self.shaderFilter.imageByFilteringImage(image) {
                self.imageView.image = out;
            }
            else {
                self.imageView.image = image;
            }
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
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {
        if info[UIImagePickerControllerOriginalImage] != nil {
            
            // ソースイメージ更新
            self.sourceImage = info[UIImagePickerControllerOriginalImage] as? UIImage;
            
            // フィルタかける
            execToonFilter();
        }
        picker.dismissViewControllerAnimated(true, completion: nil);
    }
}

