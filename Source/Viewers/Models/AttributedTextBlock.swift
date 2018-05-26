import UIKit

public enum AttributedTextBlock {
    
    case header1(String)
    case header2(String)
    case normal(String)
    case list(String)
    
    var text: NSMutableAttributedString {
        let attributedString: NSMutableAttributedString
        switch self {
        case .header1(let value):
            let attributes: [String: Any] = [NSFontAttributeName: UIFont.boldSystemFont(ofSize: 20), NSForegroundColorAttributeName: UIColor.black]
            attributedString = NSMutableAttributedString(string: value, attributes: attributes as [String : Any])
        case .header2(let value):
            let attributes: [String: Any] = [NSFontAttributeName: UIFont.boldSystemFont(ofSize: 18), NSForegroundColorAttributeName: UIColor.black]
            attributedString = NSMutableAttributedString(string: value, attributes: attributes as [String : Any])
        case .normal(let value):
            let attributes: [String: Any] = [NSFontAttributeName: UIFont.systemFont(ofSize: 15), NSForegroundColorAttributeName: UIColor.black]
            attributedString = NSMutableAttributedString(string: value, attributes: attributes as [String : Any])
        case .list(let value):
            let attributes: [String: Any] = [NSFontAttributeName: UIFont.systemFont(ofSize: 15), NSForegroundColorAttributeName: UIColor.black]
            attributedString = NSMutableAttributedString(string: "∙ " + value, attributes: attributes as [String : Any])
        }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        paragraphStyle.lineHeightMultiple = 1
        paragraphStyle.paragraphSpacing = 10
        
        attributedString.addAttribute(NSParagraphStyleAttributeName, value: paragraphStyle, range:NSMakeRange(0, attributedString.length))
        return attributedString
    }
}
