import Foundation
import UIKit
import Photos

public typealias TelegramSelection = (TelegramSelectionType) -> ()

public enum TelegramSelectionType {
    case photo([PHAsset])
}

extension UIAlertController {
    
    /// Add Telegram Picker
    ///
    /// - Parameters:
    ///   - selection: type and action for selection of asset/assets
    
    public func addTelegramPicker(selection: @escaping TelegramSelection) {
        let vc = TelegramPickerViewController(selection: selection)
        set(vc: vc)
    }
}



final public class TelegramPickerViewController: UIViewController {

    var buttons: [ButtonType] {
        return selectedAssets.count == 0
            ? [.photoOrVideo]
            : [.sendPhotos]
    }
    
    enum ButtonType {
        case photoOrVideo
        case file
        case sendPhotos
        case sendAsFile
    }
    
    // MARK: UI
    
    struct UI {
        static let rowHeight: CGFloat = 58
        static let insets: UIEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        static let minimumInteritemSpacing: CGFloat = 6
        static let minimumLineSpacing: CGFloat = 6
        static let maxHeight: CGFloat = UIScreen.main.bounds.width / 2
        static let multiplier: CGFloat = 2
        static let animationDuration: TimeInterval = 0.3
    }
    
    func title(for button: ButtonType) -> String {
        switch button {
        case .photoOrVideo: return "Photo or Video"
        case .file: return "File"
        case .sendPhotos: return "Send \(selectedAssets.count) \(selectedAssets.count == 1 ? "Photo" : "Photos")"
        case .sendAsFile: return "Send as File"
        }
    }
    
    func font(for button: ButtonType) -> UIFont {
        switch button {
        case .sendPhotos: return UIFont.boldSystemFont(ofSize: 20)
        default: return UIFont.systemFont(ofSize: 20) }
    }
    
    var preferredHeight: CGFloat {
        return UI.maxHeight / (selectedAssets.count == 0 ? UI.multiplier : 1) + UI.insets.top + UI.insets.bottom
    }
    
    func sizeFor(asset: PHAsset) -> CGSize {
        let height: CGFloat = UI.maxHeight
        let width: CGFloat = CGFloat(Double(height) * Double(asset.pixelWidth) / Double(asset.pixelHeight))
        return CGSize(width: width, height: height)
    }
    
    func sizeForItem(asset: PHAsset) -> CGSize {
        let size: CGSize = sizeFor(asset: asset)
        if selectedAssets.count == 0 {
            let value: CGFloat = size.height / UI.multiplier
            return CGSize(width: value, height: value)
        } else {
            return size
        }
    }
    
    // MARK: Properties
    private var fCollectionView: UICollectionView?
    fileprivate var collectionView: UICollectionView  {
        if(fCollectionView == nil){
            fCollectionView = UICollectionView.init(frame: .zero, collectionViewLayout: layout)
            fCollectionView!.dataSource = self
            fCollectionView!.delegate = self
            fCollectionView!.allowsMultipleSelection = true
            fCollectionView!.showsVerticalScrollIndicator = false
            fCollectionView!.showsHorizontalScrollIndicator = false
            fCollectionView!.decelerationRate = UIScrollViewDecelerationRateFast
            if #available(iOS 11.0, *){
                fCollectionView!.contentInsetAdjustmentBehavior = .never
            }
            fCollectionView!.contentInset = UI.insets
            fCollectionView!.backgroundColor = .clear
            fCollectionView!.maskToBounds = false
            fCollectionView!.clipsToBounds = false
            fCollectionView!.register(ItemWithPhoto.self, forCellWithReuseIdentifier: String(describing: ItemWithPhoto.self))
        }
        return fCollectionView!
    }
    
    private var fLayout: PhotoLayout?
    fileprivate var layout: PhotoLayout {
        get {
            if(fLayout == nil){
                fLayout = PhotoLayout()
                fLayout!.delegate = self
                fLayout!.lineSpacing = UI.minimumLineSpacing
            }
            return fLayout!
        }
    }
    
    private var fTableView: UITableView?
    fileprivate var tableView: UITableView {
        get{
            if(fTableView == nil){
                fTableView = UITableView.init(frame: .zero, style: .plain)
                fTableView!.dataSource = self
                fTableView!.delegate = self
                fTableView!.rowHeight = UI.rowHeight
                fTableView!.separatorColor = UIColor.lightGray.withAlphaComponent(0.4)
                fTableView!.separatorInset = .zero
                fTableView!.backgroundColor = nil
                fTableView!.bounces = false
                fTableView!.tableHeaderView = collectionView
                fTableView!.tableFooterView = UIView()
                fTableView!.register(LikeButtonCell.self, forCellReuseIdentifier: LikeButtonCell.identifier)

            }
            return fTableView!
        }
    }
    
    
    lazy var assets = [PHAsset]()
    lazy var selectedAssets = [PHAsset]()
    
    var selection: TelegramSelection?
    
    // MARK: Initialize
    
    required public init(selection: @escaping TelegramSelection) {
        self.selection = selection
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        Log("has deinitialized")
    }
    
    override public func loadView() {
        view = tableView
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            preferredContentSize.width = UIScreen.main.bounds.width * 0.5
        }
        
        updatePhotos()
    }
        
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutSubviews()
    }
    
    func layoutSubviews() {
        tableView.tableHeaderView?.height = preferredHeight
        preferredContentSize.height = tableView.contentSize.height
    }
    
    func updatePhotos() {
        checkStatus { [unowned self] assets in
            
            self.assets.removeAll()
            self.assets.append(contentsOf: assets)
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.collectionView.reloadData()
            }
        }
    }
    
    func checkStatus(completionHandler: @escaping ([PHAsset]) -> ()) {
        Log("status = \(PHPhotoLibrary.authorizationStatus())")
        switch PHPhotoLibrary.authorizationStatus() {
            
        case .notDetermined:
            /// This case means the user is prompted for the first time for allowing contacts
            Assets.requestAccess { [unowned self] status in
                self.checkStatus(completionHandler: completionHandler)
            }
            
        case .authorized:
            /// Authorization granted by user for this app.
            DispatchQueue.main.async {
                self.fetchPhotos(completionHandler: completionHandler)
            }
            
        case .denied, .restricted:
            /// User has denied the current app to access the contacts.
            let productName = Bundle.main.infoDictionary!["CFBundleName"]!
            let alert = UIAlertController(style: .alert, title: "Permission denied", message: "\(productName) does not have access to contacts. Please, allow the application to access to your photo library.")
            alert.addAction(title: "Settings", style: .destructive) { action in
                if let settingsURL = URL(string: UIApplicationOpenSettingsURLString) {
                    if #available(iOS 10.0, *) {
                        UIApplication.shared.open(settingsURL)
                    } else {
                        UIApplication.shared.openURL(settingsURL)
                    }
                }
            }
            alert.addAction(title: "OK", style: .cancel) { [unowned self] action in
                self.alertController?.dismiss(animated: true)
            }
            alert.show()
        }
    }
    
    func fetchPhotos(completionHandler: @escaping ([PHAsset]) -> ()) {
        Assets.fetch { [unowned self] result in
            switch result {
                
            case .success(let assets):
                completionHandler(assets)
                
            case .error(let error):
                Log("------ error")
                let alert = UIAlertController(style: .alert, title: "Error", message: error.localizedDescription)
                alert.addAction(title: "OK") { [unowned self] action in
                    self.alertController?.dismiss(animated: true)
                }
                alert.show()
            }
        }
    }
    
    func action(withAsset asset: PHAsset, at indexPath: IndexPath) {
        let previousCount = selectedAssets.count
        
        selectedAssets.contains(asset)
            ? selectedAssets.remove(asset)
            : selectedAssets.append(asset)
        selection?(TelegramSelectionType.photo(selectedAssets))
        
        let currentCount = selectedAssets.count

        if (previousCount == 0 && currentCount > 0) || (previousCount > 0 && currentCount == 0) {
            UIView.animate(withDuration: 0.25, animations: {
                self.layout.invalidateLayout()
            }) { finished in self.layoutSubviews() }
        } else {
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        }
        tableView.reloadData()
    }
    
    func action(for button: ButtonType) {
        switch button {
            
        case .photoOrVideo:
            alertController?.addPhotoLibraryPicker(flow: .vertical, paging: false,
                selection: .multiple(action: { assets in
                    self.selection?(TelegramSelectionType.photo(assets))
                }))
            
        case .file:
            
            break

        case .sendPhotos:
            alertController?.dismiss(animated: true) { [unowned self] in
                self.selection?(TelegramSelectionType.photo(self.selectedAssets))
            }
            
        case .sendAsFile:
            
            break
        }
    }
}

// MARK: - TableViewDelegate

extension TelegramPickerViewController: UICollectionViewDelegate {
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        layout.selectedCellIndexPath = layout.selectedCellIndexPath == indexPath ? nil : indexPath
        action(withAsset: assets[indexPath.item], at: indexPath)
    }
    
    public func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        action(withAsset: assets[indexPath.item], at: indexPath)
    }
}

// MARK: - CollectionViewDataSource

extension TelegramPickerViewController: UICollectionViewDataSource {
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let item = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: ItemWithPhoto.self), for: indexPath) as? ItemWithPhoto else { return UICollectionViewCell() }
        
        let asset = assets[indexPath.item]
        let size = sizeFor(asset: asset)
        
        DispatchQueue.main.async {
            Assets.resolve(asset: asset, size: size) { new in
                item.imageView.image = new
            }
        }
        
        return item
    }
}

// MARK: - PhotoLayoutDelegate

extension TelegramPickerViewController: PhotoLayoutDelegate {
    
    func collectionView(_ collectionView: UICollectionView, sizeForPhotoAtIndexPath indexPath: IndexPath) -> CGSize {
        let size: CGSize = sizeForItem(asset: assets[indexPath.item])
        //Log("size = \(size)")
        return size
    }
}

// MARK: - TableViewDelegate

extension TelegramPickerViewController: UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Log("indexPath = \(indexPath)")
        DispatchQueue.main.async {
            self.action(for: self.buttons[indexPath.row])
        }
    }
}

// MARK: - TableViewDataSource

extension TelegramPickerViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return buttons.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LikeButtonCell.identifier) as! LikeButtonCell
        cell.textLabel?.font = font(for: buttons[indexPath.row])
        cell.textLabel?.text = title(for: buttons[indexPath.row])
        return cell
    }
}
