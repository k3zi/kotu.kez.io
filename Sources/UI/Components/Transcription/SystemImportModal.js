import React from 'react';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed';
import Row from 'react-bootstrap/Row';

class SystemImportModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isSubmitting: false,
            didError: false,
            message: null,
            success: false
        };
    }

    getShareHash(shouldEncode) {
        const urlParams = new URLSearchParams(window.location.search);
        const shareHash = urlParams.get('shareHash') || '';
        return shouldEncode ? encodeURIComponent(shareHash) : shareHash;
    }

    async submit(event) {
        event.preventDefault();
        if (this.success || this.isSubmitting) {
            return;
        }
        this.setState({ isSubmitting: true, didError: false, message: null });

        const data = Object.fromEntries(new FormData(event.target));
        data.isAudiobook = !!data.isAudiobook;
        const response = await fetch(`/api/transcription/project/${this.props.project.id}/systemImport`, {
            method: 'POST',
            body: JSON.stringify(data),
            headers: {
                'Content-Type': 'application/json',
                'X-Kotu-Share-Hash': this.getShareHash(false)
            }
        });
        this.setState({
            isSubmitting: false,
            success: response.ok
        });

        if (response.ok) {
            this.props.onFinish();
        } else {
            this.setState({
                didError: result.error,
                message: result.reason
            });
        }
    }

    render() {
        return (
            <Modal {...this.props} backdrop='static' size="lg" aria-labelledby="contained-modal-title-vcenter" centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        System Import
                    </Modal.Title>
                </Modal.Header>

                <Modal.Body>
                    <Form onSubmit={(e) => this.submit(e)}>

                        <Form.Group className='mb-3' controlId="systemImportModalIsAudiobook">
                            <Form.Check type="checkbox" label="Audiobook" name='isAudiobook' />
                        </Form.Group>

                        {this.state.message && <Alert variant={this.state.didError ? 'danger' : 'info'} className='mt-3'>
                            {this.state.message}
                        </Alert>}

                        <Button variant="secondary" className='mt-3' disabled={this.state.isSubmitting} onClick={() => this.props.didCancel()}>Cancel</Button>
                        {' '}
                        <Button variant="primary" className='mt-3' type="submit" disabled={this.state.isSubmitting}>
                            {this.state.isSubmitting ? 'Importing...' : 'Import'}
                        </Button>
                    </Form>
                </Modal.Body>
            </Modal>
        );
    }
}

export default SystemImportModal;
