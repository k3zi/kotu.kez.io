import React from 'react';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import InputGroup from 'react-bootstrap/InputGroup';
import Modal from 'react-bootstrap/Modal';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed';
import Row from 'react-bootstrap/Row';
InputGroup;
class ShareURLModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isLoading: true,
            shareHashes: {}
        };
    }

    getShareHash(shouldEncode) {
        const urlParams = new URLSearchParams(window.location.search);
        const shareHash = urlParams.get('shareHash') || '';
        return shouldEncode ? encodeURIComponent(shareHash) : shareHash;
    }

    async componentDidMount() {
        const response = await fetch(`/api/transcription/project/${this.props.project.id}/shareURLs`, {
            headers: {
                'X-Kotu-Share-Hash': this.getShareHash(false)
            }
        });
        if (response.ok) {
            const shareHashes = await response.json();
            this.setState({ shareHashes, isLoading: false });
        }
    }

    onCopy(e, id) {
        const target = document.getElementById(id);
        target.select();
        target.setSelectionRange(0, 99999);
        document.execCommand('copy');

        e.target.innerText = 'Copied';
        setTimeout(() => {
            e.target.innerText = 'Copy';
        }, 3000);
    }

    render() {
        return (
            <Modal {...this.props} size="lg" aria-labelledby="contained-modal-title-vcenter" centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        Share URL to Project
                    </Modal.Title>
                </Modal.Header>

                <Modal.Body>
                    <Form.Group>
                        <Form.Label>View Only</Form.Label>
                        <InputGroup className="mb-3">
                            <Form.Control id="share-url-read-only" className="hide-scrollbar" value={`${window.location.origin}/transcription/${this.props.project.id}?shareHash=${encodeURIComponent(this.state.shareHashes.readOnly)}`} />
                            <Button variant="outline-secondary" onClick={(e) => this.onCopy(e, 'share-url-read-only')}>Copy</Button>
                        </InputGroup>
                    </Form.Group>
                    <Form.Group>
                        <Form.Label>View / Modify</Form.Label>
                        <InputGroup className="mb-3">
                            <Form.Control id="share-url-edit" className="hide-scrollbar" value={`${window.location.origin}/transcription/${this.props.project.id}?shareHash=${encodeURIComponent(this.state.shareHashes.edit)}`} />
                            <Button variant="outline-secondary" onClick={(e) => this.onCopy(e, 'share-url-edit')}>Copy</Button>
                        </InputGroup>
                    </Form.Group>
                </Modal.Body>
            </Modal>
        );
    }
}

export default ShareURLModal;
