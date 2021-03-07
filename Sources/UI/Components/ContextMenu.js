import * as clipboard from "clipboard-polyfill/text";
import React from 'react';

import Alert from 'react-bootstrap/Alert';
import Button from 'react-bootstrap/Button';
import Dropdown from 'react-bootstrap/Dropdown';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';
import Spinner from 'react-bootstrap/Spinner';

class ContextMenu extends React.Component {

    constructor(props) {
        super(props);
    }

    addClozeDeletion() {
        const fullText = this.props.target.innerText;
        const regex = new RegExp(`\{\{c(\\d)::(.*?)(::.*?)?\}\}`, 'g');
        let highestClozeIndex = 0;
        let match;
        while (match = regex.exec(fullText)) {
            const index = parseInt(match[1]);
            if (index > highestClozeIndex) {
                highestClozeIndex = index;
            }
        }

        const nextIndex = highestClozeIndex + 1;
        const text = `{{c${nextIndex}::${this.props.selection}}}`;
        this.insertTextAtCursor(text);
        this.props.onHide();
    }

    addAutoPitch() {
        this.insertTextAtCursor(`[pitch: ${this.props.selection}]`);
        this.props.onHide();
    }

    addManualPitch() {
        this.insertTextAtCursor(`[mpitch: ${this.props.selection}]`);
        this.props.onHide();
    }

    addManualFurigana() {
        this.insertTextAtCursor(`[mfurigana: ${this.props.selection}]`);
        this.props.onHide();
    }

    async copy() {
        await clipboard.writeText(this.props.selection);
        this.props.onHide();
    }

    async paste() {
        const text = await clipboard.readText();
        this.insertTextAtCursor(text);
        this.props.onHide();
    }

    insertTextAtCursor(newText) {
        const element = this.props.target;
        const selection = window.getSelection();
        const text = element.innerText;
        const isBackwards = selection.focusOffset < selection.anchorOffset;
        const startOffset = isBackwards ? selection.focusOffset : selection.anchorOffset;
        const endOffset = isBackwards ? selection.anchorOffset : selection.focusOffset;
        const before = text.substring(0, startOffset);
        const after  = text.substring(endOffset, text.length);
        element.innerText = before + newText + after;
        element.dispatchEvent(new Event('change', { bubbles: true }));
        element.dispatchEvent(new Event('input', { bubbles: true }));
        setTimeout(() => {
            const textNode = element.childNodes[0];
            const range = document.createRange();
            const end = before.length + newText.length;
            range.setStart(textNode, end);
            range.setEnd(textNode, end);
            selection.removeAllRanges();
            selection.addRange(range);
        }, 100);
    }

    render() {
        return (
            <>
                <div className={`dropdown-menu ${!!this.props.target ? 'show' : ''}`} style={{ top: `${this.props.y}px`, left: `${this.props.x}px`, zIndex: 3050, position: 'fixed' }}>
                    <Dropdown.Item onClick={() => this.addClozeDeletion()} disabled={!this.props.selection}>+ Cloze Deletion</Dropdown.Item>
                    <Dropdown.Item onClick={() => this.addAutoPitch()} disabled={!this.props.selection}>+ Auto Pitch</Dropdown.Item>
                    <Dropdown.Item onClick={() => this.addManualPitch()} disabled={!this.props.selection}>+ Manual Pitch</Dropdown.Item>
                    <Dropdown.Item onClick={() => this.addManualFurigana()} disabled={!this.props.selection}>+ Manual Furigana</Dropdown.Item>
                    <Dropdown.Divider />
                    {/*<Dropdown.Item onClick={() => this.convertToKana()} disabled={!this.props.selection}>→ Kana</Dropdown.Item>
                    <Dropdown.Item onClick={() => this.convertToPitch()} disabled={!this.props.selection}>→ Pitch</Dropdown.Item>
                    <Dropdown.Divider />*/}
                    <Dropdown.Item onClick={() => this.copy()} disabled={!this.props.selection}>Copy</Dropdown.Item>
                    <Dropdown.Item onClick={() => this.paste()}>Paste</Dropdown.Item>
                </div>
                <div onClick={() => this.props.onHide()} style={{ height: '100vh', width: '100vw', position: 'fixed', top: 0, left: 0, zIndex: 2050, display: (!!this.props.target) ? 'block' : 'none' }}></div>
            </>
        );
    }

}

export default ContextMenu;
