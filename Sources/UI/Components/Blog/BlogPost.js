import { withRouter } from 'react-router';
import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Pagination from 'react-bootstrap-4-pagination';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';

import CreatePostModal from './Modals/CreatePostModal';
import EditPostModal from './Modals/EditPostModal';
import DeletePostModal from './Modals/DeletePostModal';

import Helpers from './../Helpers';
import UserContext from './../Context/User';

class BlogPost extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            showDeletePostModal: null,
            showEditPostModal: null,
            post: null
        };
    }

    componentDidMount() {
        this.load();
    }

    async load() {
        const response = await fetch(`/api/blog/${this.props.match.params.id}`);
        if (response.ok) {
            const result = await response.json();

            this.setState({
                post: result
            });
        }
    }

    async showDeletePostModal(post) {
        this.setState({
            showDeletePostModal: post
        });
        await this.load();
    }

    async showEditPostModal(post) {
        this.setState({
            showEditPostModal: post
        });
        this.load();
    }

    render() {
        return (
            <UserContext.Consumer>{user => (
                <div>
                    {this.state.post && <>
                        <h2>
                            {this.state.post.title}
                            {' '}
                            <small><small className="text-muted">@{this.state.post.owner.username}</small></small>
                            {user.permissions.includes('blog') && <LinkContainer style={{cursor:'pointer'}} exact to={`/blog/edit/${this.state.post.id}`}>
                                <small className='float-end'><small><small>Edit <i class="bi bi-pencil-square"></i></small></small></small>
                            </LinkContainer>}
                            {this.state.post.isDraft && <small className='text-info ps-2'><small><small>(Draft)</small></small></small>}
                        </h2>
                        <hr />
                        <div dangerouslySetInnerHTML={{__html: Helpers.parseMarkdown(this.state.post.content ? this.state.post.content : '(No Content)')}}></div>
                        <EditPostModal post={this.state.showEditPostModal} onSuccess={() => this.showEditPostModal(null)} onHide={() => this.showEditPostModal(null)} />
                        <DeletePostModal post={this.state.showDeletePostModal} didDelete={() => this.showDeletePostModal(null)} didCancel={() => this.showDeletePostModal(null)} onHide={() => this.showDeletePostModal(null)} />
                    </>}
                </div>
            )
        }</UserContext.Consumer>);
    }
}

export default withRouter(BlogPost);
