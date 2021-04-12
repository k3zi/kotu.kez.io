import React from 'react';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed';
import Row from 'react-bootstrap/Row';

class AutoSyncModal extends React.Component {

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
        const response = await fetch(`/api/transcription/project/${this.props.project.id}/autoSync`, {
            method: 'POST',
            body: new FormData(event.target),
            headers: {
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
            const result = await response.json();
            this.setState({
                didError: result.error,
                message: result.reason
            });
        }
    }

    render() {
        return (
            <Modal {...this.props} size="lg" aria-labelledby="contained-modal-title-vcenter" centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        Auto Sync
                    </Modal.Title>
                </Modal.Header>

                <Modal.Body>
                    <Form onSubmit={(e) => this.submit(e)}>
                        <Form.Group>
                            <Form.Label>Original Text</Form.Label>
                            <Form.Control as='textarea' autoComplete='off' name="text" placeholder="Enter the original text" />
                        </Form.Group>

                        <Form.Group className='mt-3'>
                            <Form.Label>Subtitle File</Form.Label>
                            <Form.Control type="file" name="subtitleFile" custom />
                        </Form.Group>

                        {this.state.didError && <Alert variant="danger" className='mt-3'>
                            {this.state.message}
                        </Alert>}
                        {!this.state.didError && this.state.message && <Alert variant="info" className='mt-3'>
                            {this.state.message}
                        </Alert>}

                        <Button variant="secondary" className='mt-3' disabled={this.state.isSubmitting} onClick={() => this.props.didCancel()}>Cancel</Button>
                        {' '}
                        <Button variant="primary" className='mt-3' type="submit" disabled={this.state.isSubmitting}>
                            {this.state.isSubmitting ? 'Syncing...' : 'Sync'}
                        </Button>
                    </Form>
                </Modal.Body>
            </Modal>
        );
    }
}

export default AutoSyncModal;
