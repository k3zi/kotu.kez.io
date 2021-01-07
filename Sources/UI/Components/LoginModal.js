import React from 'react';

import Alert from 'react-bootstrap/Alert';
import Button from 'react-bootstrap/Button';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';
import Spinner from 'react-bootstrap/Spinner';

class LoginModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isSubmitting: false,
            didError: false,
            message: null,
            success: false
        };
    }

    async submit(event) {
        event.preventDefault();
        if (this.success || this.isSubmitting) {
            return;
        }
        this.setState({ isSubmitting: true, didError: false, message: null });

        const data = Object.fromEntries(new FormData(event.target));
        const response = await fetch('/api/auth/login', {
            method: 'POST',
            body: JSON.stringify(data),
            headers: {
                'Content-Type': 'application/json'
            }
        });
        const result = await response.json();
        const success = !result.error;
        this.setState({
            success
        });

        if (success) {
            setTimeout(() => {
                this.props.onHide();

                setTimeout(() => {
                    this.setState({
                        isSubmitting: false
                    });
                }, 1000);
            }, 1000);
        } else {
            this.setState({
                isSubmitting: false,
                didError: result.error,
                message: result.error ? result.reason : null
            });
        }
    }

    render() {
        return (
            <Modal {...this.props} size="lg" aria-labelledby="contained-modal-title-vcenter" centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        Login
                    </Modal.Title>
                </Modal.Header>

                <Modal.Body>
                    <Form onSubmit={(e) => this.submit(e)}>
                        <Form.Group controlId="loginModalUsername" className='mb-3'>
                            <Form.Label>Username</Form.Label>
                            <Form.Control type="text" name="username" placeholder="Enter a username" />
                        </Form.Group>

                        <Form.Group controlId="loginModalPassword" className='mb-3'>
                            <Form.Label>Password</Form.Label>
                            <Form.Control type="password" name="password" placeholder="Enter a password" />
                        </Form.Group>

                        {this.state.didError && <Alert variant="danger" className='mb-3'>
                            {this.state.message}
                        </Alert>}
                        {!this.state.didError && this.state.message && <Alert variant='info'>
                            {this.state.message}
                        </Alert>}

                        <Button className='col-12' variant="primary" type="submit" disabled={this.state.isSubmitting}>
                            {this.state.isSubmitting && <Spinner as="span" animation="border" size="sm" role="status" aria-hidden="true" />}
                            {this.state.isSubmitting ? ' Loading...' : 'Login'}
                        </Button>
                    </Form>
                </Modal.Body>
            </Modal>
        );
    }

}

export default LoginModal;
