import React, { useState } from 'react';
import ReactDOM from 'react-dom';

class ContentEditable extends React.Component {

    getTextSelection(editor) {
        const selection = window.getSelection();
        if (selection != null && selection.rangeCount > 0) {
            const range = selection.getRangeAt(0);

            return {
                start: this.getTextLength(editor, range.startContainer, range.startOffset),
                end: this.getTextLength(editor, range.endContainer, range.endOffset)
            };
        } else {
            return null;
        };
    }

    getTextLength(parent, node, offset) {
        if (!node) { return 0; }
        let textLength = 0;
        if (node && node.nodeName == '#text') {
            textLength += offset;
        } else {
            for (var i = 0; i < offset; i++) {
                textLength += this.getNodeTextLength(node.childNodes[i]);
            }
        }

        if (node != parent) {
            textLength += this.getTextLength(parent, node.parentNode, this.getNodeOffset(node));
        }

        return textLength;
    }

    getNodeTextLength(node) {
        let textLength = 0;
        if (node && node.nodeName == 'BR')
            textLength = 1;
        else if (node && node.nodeName == '#text')
            textLength = node.nodeValue.length;
        else if (node && node.childNodes != null)
            for (var i = 0; i < node.childNodes.length; i++)
                textLength += this.getNodeTextLength(node.childNodes[i]);

        return textLength;
    }

    getNodeOffset(node) {
        return node == null ? -1 : 1 + this.getNodeOffset(node.previousSibling);
    }

    getDOMNode() {
        return ReactDOM.findDOMNode(this);
    }

    componentDidMount() {
        this.ces = Math.random();
        const self = this;
        this.getDOMNode().addEventListener("selectstart", (e) => {
            const target = e.target;
            setTimeout(() => {
                if (window.getSelection()) {
                    function check() {
                        setTimeout(() => {
                            const selection = window.getSelection();
                            if (selection.baseNode.isEqualNode(target)) {
                                self.emitChange();
                                check();
                            }
                        }, 50);
                    }

                    check();
                }
                self.emitChange();
            }, 50);
        });
    }

    shouldComponentUpdate(nextProps) {
        return this.contentFromProps(nextProps) !== this.currentContent();
    }

    componentDidUpdate() {
        if (this.contentFromProps(this.props) !== this.currentContent()) {
           this.setCurrentContent(this.contentFromProps(this.props));
        }
    }

    isUsingHTML() {
        return !!this.props.html;
    }

    currentContent() {
        return this.isUsingHTML() ? this.getDOMNode().innerHTML : this.getDOMNode().innerText;
    }

    setCurrentContent(content) {
        if (this.isUsingHTML()) {
            this.getDOMNode().innerHTML = content;
        } else {
            this.getDOMNode().innerText = content;
        }
    }

    contentFromProps(props) {
        return props.html || props.value;
    }

    emitChange() {
        const node = this.getDOMNode();
        let value = node.innerText;
        const selection = this.getTextSelection(node);
        const selectionStart = selection ? selection.start : null;
        const selectionEnd = selection ? selection.end : null
        if (!this.isUsingHTML() && this.props.onChange && (value !== this.lastText || selectionStart !== this.lastSelectionStart || selectionEnd !== this.lastSelectionEnd)) {
            this.props.onChange({
                target: {
                    value,
                    selectionStart,
                    selectionEnd
                }
            });
        }

        if (this.isUsingHTML() && this.props.onHTMLClick) {
            const text = this.props.onHTMLClick();
            node.innerText = text;
            value = text;
            this.props.html = null;
        }

        this.lastText = value;
        this.lastSelectionStart = selectionStart;
        this.lastSelectionEnd = selectionEnd;
    }

    render() {
        return <div {...this.props} data-ces={this.ces} onInput={() => this.emitChange()} onBlur={() => this.emitChange()} onFocus={() => this.emitChange()} contentEditable={!this.props.disabled}>
            {this.props.html || this.props.value || ""}
        </div>;
    }

}

export default ContentEditable;
