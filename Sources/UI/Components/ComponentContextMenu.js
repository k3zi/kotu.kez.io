import * as clipboard from 'clipboard-polyfill/text';
import React from 'react';

import Alert from 'react-bootstrap/Alert';
import Button from 'react-bootstrap/Button';
import Dropdown from 'react-bootstrap/Dropdown';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';
import Spinner from 'react-bootstrap/Spinner';

class ComponentContextMenu extends React.Component {

    constructor(props) {
        super(props);
    }

    async updateWordStatus(status) {
        const word = this.props.target.dataset.frequencySurface;
        const response = await fetch(`/api/dictionary/status/${word}/${status}`, {
            method: 'POST'
        });
        if (response.ok) {
            this.props.target.classList.remove('status-unknown');
            this.props.target.classList.remove('status-learning');
            this.props.target.classList.remove('status-known');
            this.props.target.classList.add(`status-${status}`);
        }
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
                <div className={`dropdown-menu ${this.props.target ? 'show' : ''}`} style={{ top: `${this.props.y}px`, left: `${this.props.x}px`, zIndex: 3050, position: 'fixed', width: 'auto' }}>
                    <Dropdown.Header>Word Status</Dropdown.Header>
                    <Dropdown.Item onClick={() => this.updateWordStatus('known')} disabled={!this.props.selection}><i className="bi bi-plus-circle text-success"> Known</i></Dropdown.Item>
                    <Dropdown.Item onClick={() => this.updateWordStatus('learning')} disabled={!this.props.selection}><i className="bi bi-circle text-warning"> Learning</i></Dropdown.Item>
                    <Dropdown.Item onClick={() => this.updateWordStatus('unknown')} disabled={!this.props.selection}><i className="bi bi-dash-circle text-danger"> Unknown</i></Dropdown.Item>
                    <Dropdown.Divider />
                    <Dropdown.Item onClick={() => this.copy()} disabled={!this.props.selection}>Copy</Dropdown.Item>
                    <Dropdown.Item onClick={() => this.paste()}>Paste</Dropdown.Item>
                </div>
                <div onClick={() => this.props.onHide()} style={{ height: '100vh', width: '100vw', position: 'fixed', top: 0, left: 0, zIndex: 2050, display: (this.props.target) ? 'block' : 'none' }}></div>
            </>
        );
    }

}

export default ComponentContextMenu;
