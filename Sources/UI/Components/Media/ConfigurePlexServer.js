import React from 'react';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';
import Row from 'react-bootstrap/Row';

class ConfigurePlexServer extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isSubmitting: false,
            didError: false,
            message: null,
            success: false,
            request: null,
            linked: null
        };
    }

    async submit(event) {
        event.preventDefault();
        if (this.success || this.isSubmitting) {
            return;
        }
        this.setState({ isSubmitting: true, didError: false, message: null });
        const response = await fetch('/api/media/plex/signIn', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        });
        const result = await response.json();
        const success = !result.error;
        if (success) {
            this.setState({
                isSubmitting: false,
                request: result
            });
            setTimeout(() => this.checkPin(), 5000);
        } else {
            this.setState({
                isSubmitting: false,
                didError: result.error,
                message: result.error ? result.reason : null,
            });
        }
    }

    async checkPin() {
        const response = await fetch(`/api/media/plex/checkPin/${this.state.request.id}`);
        if (!response.ok) {
            setTimeout(() => this.checkPin(), 5000);
            return;
        }
        const result = await response.json();
        const linked = result.linked;
        this.setState({ linked });
        if (!linked) {
            setTimeout(() => this.checkPin(), 5000);
        }
    }

    render() {
        return (
            <Modal {...this.props} size="lg" aria-labelledby="contained-modal-title-vcenter" centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        Configure Plex Server
                    </Modal.Title>
                </Modal.Header>

                <Modal.Body>
                    {!this.state.request && <Form onSubmit={(e) => this.submit(e)}>
                        {this.state.didError && <Alert variant="danger" className='mb-3'>
                            {this.state.message}
                        </Alert>}
                        {!this.state.didError && this.state.message && <Alert variant="info" className='mb-3'>
                            {this.state.message}
                        </Alert>}

                        <Button className='col-12' variant="primary" type="submit" disabled={this.state.isSubmitting}>
                            {this.state.isSubmitting ? 'Loading...' : 'Sign In'}
                        </Button>
                    </Form>}
                    {this.state.request && !this.state.linked && <>
                        <h3 className='text-center'>Your code is: <strong>{this.state.request.code}</strong></h3>
                        <h4 className='text-center'>Visit <a target='_blank' href='https://www.plex.tv/link/' rel="noreferrer">Plex Link</a> to link your account.</h4>
                    </>}
                    {this.state.linked && <h3 className='text-center'>Your account has been successfully linked!</h3>}
                </Modal.Body>
            </Modal>
        );
    }
}

export default ConfigurePlexServer;
