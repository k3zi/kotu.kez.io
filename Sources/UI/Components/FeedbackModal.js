import React from 'react';

import Alert from 'react-bootstrap/Alert';
import Button from 'react-bootstrap/Button';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';
import Spinner from 'react-bootstrap/Spinner';

import ContentEditable from './Common/ContentEditable';

class FeedbackModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isSubmitting: false,
            didError: false,
            message: null,
            success: false,
            value: ''
        };
    }

    async submit(event) {
        event.preventDefault();
        if (this.success || this.isSubmitting) {
            return;
        }
        this.setState({ isSubmitting: true, didError: false, message: null });

        const value = this.state.value;
        const response = await fetch('/api/feedback', {
            method: 'POST',
            body: JSON.stringify({ value }),
            headers: {
                'Content-Type': 'application/json'
            }
        });
        const success = response.ok;
        this.setState({
            success
        });

        if (success) {
            setTimeout(() => {
                this.props.onHide();

                setTimeout(() => {
                    this.setState({
                        isSubmitting: false,
                        value: ''
                    });
                }, 1000);
            }, 1000);
        } else {
            const result = await response.json();
            this.setState({
                isSubmitting: false,
                didError: result.error,
                message: result.error ? result.reason : null
            });
        }
    }

    onChange(text) {
        const shouldUpdate = text.length === 0 || this.state.value.length === 0;
        this.state.value = text;
        if (shouldUpdate) {
            this.setState({ value: this.state.value });
        }
    }

    render() {
        return (
            <Modal {...this.props} size="lg" aria-labelledby="contained-modal-title-vcenter" centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        Feedback
                    </Modal.Title>
                </Modal.Header>

                <Modal.Body>
                    <Form onSubmit={(e) => this.submit(e)}>
                        <ContentEditable value={this.state.value} onChange={(e) => this.onChange(e.target.value)} className='form-control h-auto text-break plaintext' />

                        {this.state.didError && <Alert variant="danger" className='mb-3'>
                            {this.state.message}
                        </Alert>}
                        {!this.state.didError && this.state.message && <Alert className='mb-3' variant='info'>
                            {this.state.message}
                        </Alert>}

                        <Button className='col-12 mt-3' variant="primary" type="submit" disabled={this.state.isSubmitting || this.state.value.length === 0}>
                            {this.state.isSubmitting && <Spinner as="span" animation="border" size="sm" role="status" aria-hidden="true" />}
                            {this.state.isSubmitting ? ' Submitting...' : 'Submit'}
                        </Button>
                    </Form>
                </Modal.Body>
            </Modal>
        );
    }

}

export default FeedbackModal;
